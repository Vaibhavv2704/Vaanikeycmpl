from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import VoiceProfile, LivenessChallenge
import torch
import torchaudio
import google.generativeai as genai
from speechbrain.inference.speaker import EncoderClassifier
import os
import json
import uuid
import re
os.makedirs("temp_audio", exist_ok=True)

# --- CONFIGURATION ---
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY") 

genai.configure(api_key=GOOGLE_API_KEY)

# Load SpeechBrain Model
classifier = EncoderClassifier.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb", 
    run_opts={"device":"cpu"}
)

# --- HELPER: VOICE FINGERPRINTING ---
def extract_embedding(audio_file):
    filename  = f"temp_{uuid.uuid4()}.wav"
    temp_path = os.path.join("temp_audio", filename)


    with open(temp_path, 'wb') as f:
        for chunk in audio_file.chunks():
            f.write(chunk)

    try:
        # 1. Load audio
        signal, fs = torchaudio.load(temp_path)

        # 2. FORCE MONO (Fixes the 384 vs 192 error)
        # If signal has 2 channels [2, time], average them into 1 [1, time]
        if signal.shape[0] > 1:
            signal = torch.mean(signal, dim=0, keepdim=True)

        # 3. Resample to 16kHz
        if fs != 16000:
            resampler = torchaudio.transforms.Resample(fs, 16000)
            signal = resampler(signal)

        # 4. Generate fingerprint
        with torch.no_grad():
            embeddings = classifier.encode_batch(signal)
            embedding_flat = embeddings.flatten()
        
        return embedding_flat.tolist()
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

# --- 1. ENROLL API ---
class EnrollView(APIView):
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        try:
            name = request.data.get('name')
            audio_file = request.FILES.get('audio')

            if not name or not audio_file:
                return Response({"error": "Missing name or audio"}, status=400)

            embedding = extract_embedding(audio_file)
            
            profile, created = VoiceProfile.objects.update_or_create(
                name=name,
                defaults={'embedding_json': ""} 
            )
            profile.set_embedding(embedding)
            profile.save()

            return Response({"message": f"Voice profile created for {name}"})
        except Exception as e:
            return Response({"error": str(e)}, status=500)

# --- 2. VERIFY API ---
class VerifyView(APIView):
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        THRESHOLD = 0.35
        try:
            name = request.data.get('name')
            audio_file = request.FILES.get('audio')

            try:
                profile = VoiceProfile.objects.get(name=name)
                # Ensure saved data is a 1D Tensor
                saved_embedding = torch.tensor(profile.get_embedding()).flatten()
            except VoiceProfile.DoesNotExist:
                print(f"--- VERIFY ATTEMPT FAILED ---")
                print(f"User '{name}' not found in database.")
                print(f"-----------------------------")
                return Response({
                    "match": False, 
                    "reason": "User not enrolled", 
                    "threshold": THRESHOLD
                })

            # Get New Data and ensure it's a 1D Tensor
            new_val = extract_embedding(audio_file)
            new_embedding = torch.tensor(new_val).flatten()

            # Calculate Cosine Similarity on 1D vectors (dim=0)
            # This returns a single-element tensor
            similarity_tensor = torch.nn.functional.cosine_similarity(
                saved_embedding, 
                new_embedding, 
                dim=0
            )
            
            # Now safely convert that single-element tensor to a Python float
            similarity = similarity_tensor.item()
             
            is_match = similarity > THRESHOLD

            # ADD THIS PRINT LINE
            print(f"\n--- VOICE VERIFY ATTEMPT ---")
            print(f"User:      {name}")
            print(f"Score:     {similarity:.4f}")
            print(f"Threshold: {THRESHOLD}")
            print(f"Status:    {'[MATCHED]' if is_match else '[FAILED]'}")
            print(f"---------------------------\n")

            return Response({
                "match": bool(is_match),
                "confidence": round(float(similarity), 4),
                "threshold": THRESHOLD
            })
        except Exception as e:
            # Print error to terminal for debugging
            print(f"VERIFY ERROR: {e}")
            return Response({"error": str(e)}, status=500)

# --- 3. TEXT PROCESSING (GEMINI) ---
class ProcessTextView(APIView):
    def post(self, request):
        text = request.data.get('text')
        if not text: 
            return Response({"error": "No text provided"}, status=400)
        
        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            prompt = (
                f"Extract banking details from: '{text}'. "
                "Return ONLY valid JSON in this exact form : {'amount': number, 'receiver': 'string'}. "
                "Do not include markdown formatting like ```json."
                "No extra text."
            )
            response = model.generate_content(prompt)

            raw_text = response.text
            clean_json = re.sub(r'```json|```', '', raw_text).strip()
            data = json.loads(clean_json)
            return Response({"google_analysis": response.text})

            try:
                # Convert the string into a real Python dictionary
                data = json.loads(clean_json)
                return Response({"google_analysis": data})
            except json.JSONDecodeError:
                # If parsing fails, return the string so you can still see it
                return Response({"google_analysis": clean_json, "warning": "Partial parse error"})


        except Exception as e:
            return Response({"error": str(e)}, status=500)
        # except Exception:
        #      return Response({"google_analysis": "{'amount': 0, 'receiver': 'error'}"})


class GenerateChallengeView(APIView):
    def post(self, request):
        name = request.data.get('name')
        if not name:
            return Response({"error": "Name is required"}, status=400)
        
        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            prompt = (
                "Generate a random, natural, medium-length sentence (10-15 words) "
                "for a voice liveness test. Do not use quotes or markdown."
                "Do not generate anything extra."
            )
            response = model.generate_content(prompt)
            sentence = response.text.strip()

            # Store in DB so we can verify it later
            LivenessChallenge.objects.update_or_create(
                name=name,
                defaults={'challenge_text': sentence}
            )

            return Response({
                "name": name,
                "challenge": sentence
            })
        except Exception as e:
            return Response({"error": str(e)}, status=500)

# --- 5. VERIFY LIVENESS (SPEECH TO TEXT) ---
class VerifyLivenessView(APIView):
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        name = request.data.get('name')
        audio_file = request.FILES.get('audio')

        if not name or not audio_file:
            return Response({"error": "Missing name or audio"}, status=400)

        try:
            # 1. Get the expected text from DB
            challenge = LivenessChallenge.objects.filter(name=name).latest('created_at')
            expected_text = challenge.challenge_text.lower().strip()
            # Remove punctuation for cleaner comparison
            expected_text = re.sub(r'[^\w\s]', '', expected_text)

            # 2. Save audio temporarily for Gemini to read
            temp_path = f"temp_liveness_{name}.wav"
            with open(temp_path, 'wb') as f:
                for chunk in audio_file.chunks():
                    f.write(chunk)

            # 3. Use Gemini for Speech-to-Text
            model = genai.GenerativeModel('gemini-2.5-flash')
            
            # Upload to Gemini's temporary storage
            audio_data = genai.upload_file(path=temp_path, mime_type="audio/wav")
            
            response = model.generate_content([
                "Transcribe this audio exactly as spoken. Return only the transcription.",
                audio_data
            ])
            
            transcribed_text = response.text.lower().strip()
            transcribed_text = re.sub(r'[^\w\s]', '', transcribed_text)

            # 4. Cleanup temp files
            os.remove(temp_path)

            # 5. Compare (Simple word-overlap check)
            # We check if the transcribed text is similar to the expected text
            # You can make this more strict or use fuzzy matching
            is_valid = (expected_text in transcribed_text) or (transcribed_text in expected_text)

            return Response({
                "name": name,
                "expected": expected_text,
                "transcribed": transcribed_text,
                "match": is_valid
            })

        except LivenessChallenge.DoesNotExist:
            return Response({"error": "No challenge found for this user. Generate one first."}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=500)
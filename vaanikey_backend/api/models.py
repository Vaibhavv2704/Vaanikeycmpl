from django.db import models
import json

class VoiceProfile(models.Model):
    name = models.CharField(max_length=100, unique=True)
    # Stores the 192-number vector as a string
    embedding_json = models.TextField() 

    def __str__(self):
        return self.name

    def set_embedding(self, vector_list):
        self.embedding_json = json.dumps(vector_list)

    def get_embedding(self):
        return json.loads(self.embedding_json)


class LivenessChallenge(models.Model):
    name = models.CharField(max_length=100)
    challenge_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.challenge_text[:20]}"
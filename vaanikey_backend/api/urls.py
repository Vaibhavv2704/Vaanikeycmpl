from django.urls import path
from .views import EnrollView, VerifyView, ProcessTextView, GenerateChallengeView, VerifyLivenessView

urlpatterns = [
    path('enroll/', EnrollView.as_view()),
    path('verify/', VerifyView.as_view()),
    path('process-text/', ProcessTextView.as_view()),
    path('generate-challenge/', GenerateChallengeView.as_view()),
    path('verify-liveness/', VerifyLivenessView.as_view()),

]
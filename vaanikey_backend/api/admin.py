from django.contrib import admin
from .models import VoiceProfile

@admin.register(VoiceProfile)
class VoiceProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'id') # This shows the name in the database table view
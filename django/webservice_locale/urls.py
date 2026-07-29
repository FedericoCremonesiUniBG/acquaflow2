from django.urls import path, include

# Rimosso "from django.contrib import admin" e la rotta 'admin/' che usava:
# portava al pannello di amministrazione di Django, che non esiste piu' avendo
# tolto 'django.contrib.admin' da INSTALLED_APPS in settings.py.
urlpatterns = [
    path('api/', include('api.urls')),
]

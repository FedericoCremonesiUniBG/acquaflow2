from django.urls import path
from . import views

urlpatterns = [
    path('clienti/', views.importa_clienti),
    path('punti-fornitura/', views.importa_punti_fornitura),
    path('utenze/', views.importa_utenze),
    path('fatture/', views.importa_fatture),
    path('letture/', views.importa_letture),
]

import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .models import Cliente, PuntoFornitura, Utenza, Fattura, Lettura


def _importa_batch(model, request, fk_fields=None):
    fk_fields = fk_fields or []

    try:
        record_list = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "JSON non valido."}, status=400)

    try:
        istanze = []
        for record in record_list:
            for campo in fk_fields:
                if campo in record:
                    record[campo + "_id"] = record.pop(campo)
            istanze.append(model(**record))

        model.objects.bulk_create(istanze, ignore_conflicts=True)
    except Exception as e:
        return JsonResponse({"success": False, "message": str(e)}, status=500)

    return JsonResponse({"success": True, "inseriti": len(istanze)})


@csrf_exempt
@require_POST
def importa_clienti(request):
    return _importa_batch(Cliente, request)


@csrf_exempt
@require_POST
def importa_punti_fornitura(request):
    return _importa_batch(PuntoFornitura, request)


@csrf_exempt
@require_POST
def importa_utenze(request):
    return _importa_batch(Utenza, request, fk_fields=["codice_pod", "cliente"])


@csrf_exempt
@require_POST
def importa_fatture(request):
    return _importa_batch(Fattura, request, fk_fields=["utenza", "cliente"])


@csrf_exempt
@require_POST
def importa_letture(request):
    return _importa_batch(Lettura, request, fk_fields=["utenza", "fattura"])

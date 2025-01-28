from fastapi import APIRouter

from motor_aposta.module.aposta.services.calculo_service import calcular_dezenas


router = APIRouter(prefix="/calculo")

@router.get("/dezenas")
async def calcula_dezenas(id_tipo_jogo: int):
    response = await calcular_dezenas(id_tipo_jogo)
    return response
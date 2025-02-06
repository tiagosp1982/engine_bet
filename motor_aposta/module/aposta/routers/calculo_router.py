from fastapi import APIRouter
from motor_aposta.module.aposta.services.calculo_service import calcular_dezenas


router = APIRouter(prefix="/calculo")

@router.get("/dezenas/{id_tipo_jogo}/{nr_concurso_inicial}/{nr_concurso_final}")
async def calcula_dezenas(id_tipo_jogo: int, nr_concurso_inicial: int, nr_concurso_final: int):
    response = await calcular_dezenas(id_tipo_jogo, nr_concurso_inicial, nr_concurso_final)
    return response
from fastapi import APIRouter
from motor_aposta.module.aposta.services.resultado_service import confere_resultado_detalhado


router = APIRouter(prefix="/resultado_detalhado")


@router.get("/")
async def resultado_detalhado(tipo_jogo: int, lista_bet: str):
    response = await confere_resultado_detalhado(tipo_jogo, lista_bet)
    return response
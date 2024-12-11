from fastapi import APIRouter
from motor_aposta.module.aposta.services.service import confere_resultado_consolidado


router = APIRouter(prefix="/resultado_consolidado")


@router.get("/")
async def resultado_consolidado(id_tipo_jogo: int, lista_bet: str):
    response = await confere_resultado_consolidado(id_tipo_jogo, lista_bet)
    return response
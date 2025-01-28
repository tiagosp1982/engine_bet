from fastapi import APIRouter
from motor_aposta.module.aposta.services.importacao_service import importa_resultado_por_tipo_jogo


router = APIRouter(prefix="/resultado")


@router.post("/atualizar")
async def importa_resultado(tipo_jogo: int):
    response = await importa_resultado_por_tipo_jogo(tipo_jogo)
    return response
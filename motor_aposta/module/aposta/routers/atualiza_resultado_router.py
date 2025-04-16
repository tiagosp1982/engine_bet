from fastapi import APIRouter
from motor_aposta.module.aposta.services.importacao_service import importa_resultado_por_tipo_jogo


router = APIRouter(prefix="/resultado")


@router.post("/atualizar/{id_tipo_jogo}")
async def importa_resultado(id_tipo_jogo: int):
    response = await importa_resultado_por_tipo_jogo(id_tipo_jogo)
    return response
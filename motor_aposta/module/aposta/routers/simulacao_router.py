from fastapi import APIRouter
from motor_aposta.module.aposta.services.simulacao_service import cria_simulacao


router = APIRouter(prefix="/simulacao")


@router.post("/cria_simulacao")
async def incluir_simulacao(id_tipo_jogo: int, id_usuario: int, jogo: str):
    response = await cria_simulacao(id_tipo_jogo=id_tipo_jogo, id_usuario=id_usuario, jogo=jogo)
    return response
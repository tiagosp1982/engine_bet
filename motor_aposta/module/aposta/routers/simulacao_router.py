from fastapi import APIRouter
from motor_aposta.module.aposta.services.simulacao_service import cria_simulacao


router = APIRouter(prefix="/simulacao")


@router.post("/cria_simulacao/{id_tipo_jogo}/{id_usuario}/{nr_jogo}")
async def incluir_simulacao(id_tipo_jogo: int, id_usuario: int, nr_jogo: str):
    response = await cria_simulacao(id_tipo_jogo=id_tipo_jogo,
                                    id_usuario=id_usuario,
                                    jogo=nr_jogo)
    return response
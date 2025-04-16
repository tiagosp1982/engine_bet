from fastapi import APIRouter
from motor_aposta.module.aposta.services.aposta_service import cria_aposta


router = APIRouter(prefix="/aposta")


@router.post("/criar_aposta/{id_tipo_jogo}/{id_usuario}/{nr_jogo}")
async def incluir_aposta(id_tipo_jogo: int, id_usuario: int, nr_jogo: str):
    response = await cria_aposta(id_tipo_jogo,id_usuario,nr_jogo)
    return response
from fastapi import APIRouter
from motor_aposta.module.aposta.services.concurso_service import lista_concurso


router = APIRouter(prefix="/concurso")

@router.get("/listar/{id_tipo_jogo}")
async def listar(id_tipo_jogo: int):
    response = await lista_concurso(id_tipo_jogo)
    return response
from fastapi import APIRouter
from motor_aposta.module.aposta.services.tipo_jogo_service import lista_tipo_jogo


router = APIRouter(prefix="/tipo_jogo")

@router.get("/listar")
async def listar_tipo_jogo():
    response = await lista_tipo_jogo()
    return response
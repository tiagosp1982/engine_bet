from fastapi import APIRouter
from motor_aposta.module.aposta.services.tipo_jogo_service import lista_tipo_jogo
from motor_aposta.module.aposta.services.tipo_jogo_service import lista_tipo_jogo_estrutura
from motor_aposta.module.aposta.services.tipo_jogo_service import lista_tipo_jogo_por_id


router = APIRouter(prefix="/tipo_jogo")

@router.get("/listar")
async def listar_tipo_jogo():
    response = await lista_tipo_jogo()
    return response

@router.get("/listar_por_codigo/{id_tipo_jogo}")
async def listar_tipo_jogo_por_codigo(id_tipo_jogo:int):
    response = await lista_tipo_jogo_por_id(id_tipo_jogo)
    return response

@router.get("/listar_estrutura/{id_tipo_jogo}")
async def listar_tipo_jogo_estrutura(id_tipo_jogo:int):
    response = await lista_tipo_jogo_estrutura(id_tipo_jogo)
    return response
from fastapi import APIRouter
from motor_aposta.module.aposta.dtos.usuario_dto import UsuarioDTO
from motor_aposta.module.aposta.services.usuario_service import valida_usuario


router = APIRouter(prefix="/usuario")

@router.get("/logar/{email}/{senha}")
async def logar(email: str, senha: str):
    response = await valida_usuario(email=email, senha=senha)
    return response

@router.post("/cadastrar")
async def cadastrar_usuario(usuario: UsuarioDTO):
    return usuario
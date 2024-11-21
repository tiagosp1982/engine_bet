from fastapi import APIRouter
from engine_bet.module.bet.services.simulation_service import add_simulation


router = APIRouter(prefix="/simulation")


@router.post("/add_simulation")
async def post_add_simulation(id_tipo_jogo: int, id_usuario: int, jogo: str):
    response = await add_simulation(id_tipo_jogo=id_tipo_jogo, id_usuario=id_usuario, jogo=jogo)
    return response
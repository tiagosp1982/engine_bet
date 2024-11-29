from fastapi import APIRouter
from engine_bet.module.importer.services import update_sorteio_all


router = APIRouter(prefix="/update_bet_all")


@router.post("/update_sorteio_all")
async def post_update_bet_all(tipo_jogo: int):
    response = await update_sorteio_all(tipo_jogo)
    return response
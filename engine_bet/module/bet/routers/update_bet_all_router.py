from fastapi import APIRouter
from engine_bet.module.importer.services import update_raffle_all


router = APIRouter(prefix="/update_bet_all")


@router.post("/update_raffle_all")
async def post_update_bet_all(tipo_jogo: int):
    response = await update_raffle_all(tipo_jogo)
    return response
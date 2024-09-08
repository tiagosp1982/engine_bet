from fastapi import APIRouter
from engine_bet.module.importer.services import update_raffle_all


router = APIRouter(prefix="/update_bet_all")


@router.post("/")
async def post_update_bet_all():
    response = await update_raffle_all()
    return response
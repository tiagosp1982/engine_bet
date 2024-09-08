from fastapi import APIRouter
from engine_bet.module.bet.services.service import confer_bet_total


router = APIRouter(prefix="/confer_result_bet_total")


@router.get("/")
async def get_result_bet_total(list_bet):
    response = await confer_bet_total(list_bet)
    return response
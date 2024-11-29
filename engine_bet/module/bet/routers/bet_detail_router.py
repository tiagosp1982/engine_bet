from fastapi import APIRouter
from engine_bet.module.bet.services.service import confer_bet_detail


router = APIRouter(prefix="/confer_result_bet_detail")


@router.get("/")
async def get_result_bet_detail(type_bet: int, lista_bet: str):
    response = await confer_bet_detail(type_bet, lista_bet)
    return response
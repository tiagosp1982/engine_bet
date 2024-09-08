from fastapi import APIRouter
from engine_bet.module.bet.services.service import confer_bet_detail


router = APIRouter(prefix="/confer_result_bet_detail")


@router.get("/")
async def get_result_bet_detail(list_bet):
    response = await confer_bet_detail(list_bet)
    return response
import uvicorn
from fastapi import FastAPI
from engine_bet.module.bet.routers import bet_detail_router, bet_total_router, update_bet_all_router, simulation_router


app = FastAPI()


app.include_router(update_bet_all_router.router)
app.include_router(bet_detail_router.router)
app.include_router(bet_total_router.router)
app.include_router(simulation_router.router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)

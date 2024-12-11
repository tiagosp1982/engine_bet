import uvicorn
from fastapi import FastAPI
from motor_aposta.module.aposta.routers import atualiza_resultado_router, resultado_consolidado_router, resultado_detalhado_router, simulacao_router


app = FastAPI()


app.include_router(atualiza_resultado_router.router)
app.include_router(resultado_detalhado_router.router)
app.include_router(resultado_consolidado_router.router)
app.include_router(simulacao_router.router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)

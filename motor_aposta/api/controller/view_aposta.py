import uvicorn
from fastapi import FastAPI
from motor_aposta.module.aposta.routers import atualiza_resultado_router 
from motor_aposta.module.aposta.routers import resultado_router 
from motor_aposta.module.aposta.routers import simulacao_router 
from motor_aposta.module.aposta.routers import usuario_router
from motor_aposta.module.aposta.routers import tipo_jogo_router
from motor_aposta.module.aposta.routers import calculo_router


app = FastAPI()


app.include_router(atualiza_resultado_router.router)
app.include_router(resultado_router.router)
app.include_router(simulacao_router.router)
app.include_router(usuario_router.router)
app.include_router(tipo_jogo_router.router)
app.include_router(calculo_router.router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)

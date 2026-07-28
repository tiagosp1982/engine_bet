import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from motor_aposta.module.aposta.routers import atualiza_resultado_router 
from motor_aposta.module.aposta.routers import resultado_router 
from motor_aposta.module.aposta.routers import simulacao_router 
from motor_aposta.module.aposta.routers import usuario_router
from motor_aposta.module.aposta.routers import tipo_jogo_router
from motor_aposta.module.aposta.routers import calculo_router
from motor_aposta.module.aposta.routers import concurso_router
from motor_aposta.module.aposta.routers import aposta_router


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(atualiza_resultado_router.router)
app.include_router(aposta_router.router)
app.include_router(resultado_router.router)
app.include_router(simulacao_router.router)
app.include_router(usuario_router.router)
app.include_router(tipo_jogo_router.router)
app.include_router(calculo_router.router)
app.include_router(concurso_router.router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)

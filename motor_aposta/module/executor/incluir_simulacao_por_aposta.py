
from itertools import combinations
from motor_aposta.module.aposta.dtos.aposta_carrinho_dto import ApostaCarrinhoDto
from motor_aposta.module.aposta.repositories.aposta_repository import aposta_repository
from motor_aposta.module.aposta.services.simulacao_service import gera_simulacao

id_tipo_jogo = 1
id_usuario = 1
nr_concurso = 3540

apostas:ApostaCarrinhoDto = aposta_repository.busca_aposta_carrinho(id_tipo_jogo, id_usuario, nr_concurso)
for aposta in apostas:
    if aposta.id_aposta != 19:
        gera_simulacao(id_tipo_jogo=id_tipo_jogo, id_usuario=id_usuario, jogo=aposta.jogo)
        print(f'Gerada simulação da aposta: {aposta.id_aposta}')
import random

import numpy as np

from motor_aposta.module.aposta.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.repositories.simulacao_repository import simulacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.services.calculo_service import calcula_dezenas
from motor_aposta.module.aposta.services.resultado_service import sorteio_por_id, gera_aposta, valida_resultado
from motor_aposta.module.aposta.services.simulacao_service import gera_simulacao

def gera_jogo(id: int,
              id_usuario: int,
              qtde_aposta: int,
              qtde_dezena_aposta: int,
              somente_ausente: bool,
              amarrar_jogos: bool) -> str:

    jogo_curto = False
    grava_simulacao = True
    tipo_jogo: TipoJogoDTO
    tipo_jogo_estrutura: TipoJogoEstruturaDTO
    tipo_jogo_premiacao: TipoJogoPremiacaoDTO
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id)
    tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id)
    tipo_jogo_premiacao = tipo_jogo_repository.busca_tipo_jogo_premiacao(id)

    qtde_maxima_dezenas_repetidas_entre_jogos = tipo_jogo_premiacao.qt_dezena_acerto
    if not (amarrar_jogos):
        qtde_maxima_dezenas_repetidas_entre_jogos -= 1

    if (qtde_dezena_aposta < tipo_jogo.qt_dezena_minima_aposta):
        print('Quantidade de dezenas da aposta é menor do que a quantidade mínima permitida.')
        exit()

    if (qtde_dezena_aposta > tipo_jogo.qt_dezena_maxima_aposta):
        print('Quantidade de dezenas da aposta é maior do que a quantidade máxima permitida.')
        exit()

    dados = sorteio_por_id(id, False)
    sorteios = SorteioFactory.ConverterListaSorteio(dados)
    numeros_total = len(tipo_jogo_estrutura)
    n_sorteios = len(sorteios)

    dezenas_filtrar = 0
    resultado_anterior = ""
    total_repetido = 0
    for s in sorteios:
        if (not resultado_anterior == ''):
            total_repetido += len(set(s) & set(resultado_anterior))
        resultado_anterior = s
    dezenas_filtrar = int((total_repetido / n_sorteios).__round__(0))

    if not ((numeros_total / 2) > tipo_jogo.qt_dezena_minima_aposta):
        # Para os casos de lotofacil pq temos 10 ausentes e o mínimo de dezenas são 15.
        # Neste caso, o parametro informado é invalidado
        jogo_curto = True
        somente_ausente = False

    qtde_adicional_ausente = 0
    qtde_adicional_repetido = 0

    if (qtde_adicional_numeros:= qtde_dezena_aposta - tipo_jogo.qt_dezena_minima_aposta):
        index = 1
        while index <= qtde_adicional_numeros:
            if (index % 2 != 0):
                qtde_adicional_ausente += 1
            else:
                qtde_adicional_repetido += 1
            index += 1

    # Calcula a medio do desvio padrão
    estatisticas = []
    for i, row in enumerate(sorteios):
        std_dev = np.std(row)
        estatisticas.append((std_dev))

    desvio_total = sum(desvio for desvio in estatisticas)
    media_desvio = (desvio_total / len(sorteios)).__round__(2)
    
    # Service de Calculos
    calculos = calcula_dezenas(id)
    
    # Repositório de simulação
    simulacao = simulacao_repository.busca_ultima_simulacao(id_tipo_jogo=id,
                                                            id_usuario=id_usuario,
                                                            nr_concurso_aposta=tipo_jogo.nr_concurso_max)

    id_simulacao = (simulacao.id_simulacao if simulacao else 0)
    for i in range(qtde_aposta):
        jogo_invalido = True
        id_simulacao += 1
        while jogo_invalido:
            if (jogo_curto):
                index = random.randrange(1,2)
            else:
                index = random.randrange(0,1)

            qt_filtrar = random.randrange(dezenas_filtrar - index, 
                                            dezenas_filtrar + index)

            qt_filtrar_ausente=(tipo_jogo.qt_dezena_minima_aposta-qt_filtrar)+qtde_adicional_ausente
            qt_filtrar_repetido=(qt_filtrar+qtde_adicional_repetido)
            jogo = gera_aposta(calculos=list(calculos),
                                qtde_filtrar_ausente=qt_filtrar_ausente,
                                qtde_filtrar_repetido=qt_filtrar_repetido,
                                somente_ausente=somente_ausente
                                )

            jogo_invalido = valida_resultado(id_tipo_jogo=id,
                                            apostas=",".join(map(str, jogo)),
                                            qtde_maxima_repetida_simulacao_resultado=qtde_maxima_dezenas_repetidas_entre_jogos,
                                            desvio_medio=media_desvio,
                                            sempre_amarrar_jogos=amarrar_jogos,
                                            id_usuario=id_usuario
                                            )

        if (grava_simulacao):
            simulacao = gera_simulacao(id_tipo_jogo=id,
                                       id_usuario=id_usuario,
                                        jogo=",".join(map(str, jogo)))
        return jogo

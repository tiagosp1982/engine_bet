import numpy as np
import random
from motor_aposta.module.aposta.dtos.calculo_dto import CalculoDTO
from motor_aposta.module.aposta.factories.simulacao_factory import SimulacaoFactory
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
from motor_aposta.module.aposta.repositories.simulacao_repository import simulacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository

def __init__(cls):
        pass

async def confere_resultado_detalhado(id_tipo_jogo: int, apostas: str) -> dict:
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo)
    lista_resultado = []

    aposta = apostas.split(',')
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append({"Concurso": s[0], "Acertos": len(resultado)})
    
    return lista_resultado

async def confere_resultado_consolidado(id_tipo_jogo: int, apostas: str) -> dict:
    lista_total = confere_resultado(id_tipo_jogo, apostas)
    return lista_total

def sorteio_by_id(id_tipo_jogo: int, ciclo: bool, historico: bool = False) -> dict:
    tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id_tipo_jogo)
    limit_data = len(tipo_jogo_estrutura)
    if (historico):
        tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
        limit_data = tipo_jogo.nr_concurso_max

    if (ciclo):
        sorteio = sorteio_repository.busca_sorteio_por_ciclo(id_tipo_jogo)
        if (sorteio == None):
            sorteio = sorteio_repository.busca_sorteio(id_tipo_jogo, limit_data)
    else:
        sorteio = sorteio_repository.busca_sorteio(id_tipo_jogo, limit_data)
    
    return SorteioFactory.ConverterDto(id_tipo_jogo, sorteio)

def gera_aposta(calculos: list[CalculoDTO],
                     qtde_filtrar_ausente: int,
                     qtde_filtrar_repetido: int,
                     somente_ausente: bool) -> dict:
   
    ausente = [c for c in calculos if c.QtAusenciaRecente > 0]
    ausente = sorted(ausente, key=lambda p: p.QtAusenciaRecente, reverse=True)
    ausente = [a.NrDezena for a in ausente]
    if (qtde_filtrar_ausente > len(ausente)):
        sobra = qtde_filtrar_ausente - (len(ausente) - 1)
        qtde_filtrar_ausente = (len(ausente) - 1)
        qtde_filtrar_repetido = qtde_filtrar_repetido + sobra

    repeticao = [c for c in calculos if c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= qtde_filtrar_repetido]
    repeticao = sorted(repeticao, key=lambda p: p.QtRepeticaoRecente, reverse=True)
    repeticao = [a.NrDezena for a in repeticao]

    jogo_ausente = random.sample(ausente, k=(qtde_filtrar_ausente if not somente_ausente else qtde_filtrar_ausente + qtde_filtrar_repetido))
    jogo_repeticao = random.sample(repeticao, k=(qtde_filtrar_repetido if not somente_ausente else 0))
    
    jogo = sorted(jogo_ausente + jogo_repeticao)

    return jogo

def confere_resultado(id_tipo_jogo: int, apostas: str):
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo)
    premiacoes = tipo_jogo_repository.busca_dezenas_premiacao(id_tipo_jogo)
    lista_total = []
    
    aposta = apostas.split(', ')
    lista_resultado = calcula_resultados(aposta, sorteios)
    for p in premiacoes:
        prm = p[0]
        acertos = [acerto for acerto in lista_resultado if acerto == prm]
        if (len(acertos)) > 0:
            lista_total.append({"Dezenas": prm, "Acertos": len(acertos)})
        else:
            lista_total.append({"Dezenas": prm, "Acertos": 0})
    
    return lista_total
    
    
def calcula_resultados(aposta: list[str], sorteios: dict) -> list:
    resultados = []
    for s in sorteios:
        sorteioString = str(s[1])
        sorteio = sorteioString.split(', ')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        resultados.append(len(resultado))
    return resultados

def valida_resultado(id_tipo_jogo: int,
                    apostas: str,
                    qtde_maxima_repetida_simulacao_resultado: int = None,
                    desvio_medio: float = None,
                    sempre_amarrar_jogos: bool = False,
                    id_usuario: int = 0
                    ):

    resultado: bool = False
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo)
    aposta = apostas.split(',')
    lista_resultado = calcula_resultados(aposta, sorteios)
    lista_simulado = []

    # Valida se o jogo já foi sorteado com a qtde máxima por tipo de jogo
    acerto = [a for a in lista_resultado if a == tipo_jogo.qt_dezena_resultado]
    resultado = (len(acerto) > 0)
    # Verifica se já foi sorteado
    if (resultado):
        return True
    
    # Verifica desvio padrão da aposta gerada
    perc_desvio = (desvio_medio * 0.2)
    desvio_gerado = []
    desvio_gerado.append([int(n) for n in aposta])
    for i, row in enumerate(desvio_gerado):
        dev = np.std(row)
    # Verifica se o jogo gerado está dentro da média de desvio padrão + 20% ou na média de desvio padrão - 20%
    if ((dev > (desvio_medio + perc_desvio).__round__(2)) or (dev < (desvio_medio - perc_desvio).__round__(2))):
        return True
    # Valida os jogos já gerados para esse concurso
    dados = simulacao_repository.busca_simulacao_item(id_tipo_jogo=id_tipo_jogo, 
                                                       id_usuario=id_usuario,
                                                       nr_concurso_aposta=tipo_jogo.nr_concurso_max)
    simulados = SimulacaoFactory.simulationOnly(dados)    
    if (simulados):
        for simulado in simulados:
            resultado = [n for n in aposta if n in simulado]
            lista_simulado.append(len(resultado))
        if (sempre_amarrar_jogos):
            acerto_jogo_adicional = [s for s in lista_simulado if s >= qtde_maxima_repetida_simulacao_resultado]
            resultado = (len(acerto_jogo_adicional) == 0)
        else:
            acerto_jogo_adicional = [s for s in lista_simulado if s > qtde_maxima_repetida_simulacao_resultado]
            resultado = (len(acerto_jogo_adicional) > 0)
        return resultado
    else:
        return False

    

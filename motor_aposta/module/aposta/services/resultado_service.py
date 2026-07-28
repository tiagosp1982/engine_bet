import numpy as np
import random
from motor_aposta.module.aposta.dtos.calculo_dto import CalculoDTO
from motor_aposta.module.aposta.dtos.sorteio_dto import SorteioAgrupadoDTO, SorteioDTO
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
        sorteioString = str(s["dezenas"])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        lista_resultado.append({"Concurso": s["nr_concurso"], "Acertos": len(resultado)})
    
    return lista_resultado

async def confere_resultado_consolidado(id_tipo_jogo: int, apostas: str) -> dict:
    lista_total = confere_resultado(id_tipo_jogo, apostas)
    return lista_total

def sorteio_por_id(id_tipo_jogo: int, ciclo: bool, historico: bool = False) -> dict:
    if (ciclo):
        sorteio = sorteio_repository.busca_sorteio_por_ciclo(id_tipo_jogo)
        if (sorteio == None):
            sorteio = sorteio_repository.busca_sorteio(id_tipo_jogo, 5)
    else:
        sorteio = sorteio_repository.busca_sorteio(id_tipo_jogo, 5)
    
    return SorteioFactory.ConverterDto(id_tipo_jogo, sorteio)

def gera_aposta(calculos: list[CalculoDTO],
                     qtde_filtrar_ausente: int,
                     qtde_filtrar_repetido: int,
                     somente_ausente: bool) -> dict:
   
    ausente = [c for c in calculos if c.QtAusenciaRecente > 0]
    ausente = sorted(ausente, key=lambda p: p.VlProbabilidade, reverse=True)
    ausente = [a.NrDezena for a in ausente]
    if (qtde_filtrar_ausente > len(ausente)):
        sobra = qtde_filtrar_ausente - (len(ausente) - 1)
        qtde_filtrar_ausente = (len(ausente) - 1)
        qtde_filtrar_repetido = qtde_filtrar_repetido + sobra

    repeticao = [c for c in calculos if c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= qtde_filtrar_repetido]
    repeticao = sorted(repeticao, key=lambda p: p.VlProbabilidade, reverse=True)
    repeticao = [a.NrDezena for a in repeticao]

    jogo_ausente = random.sample(ausente, k=(qtde_filtrar_ausente if not somente_ausente else qtde_filtrar_ausente + qtde_filtrar_repetido))
    jogo_repeticao = random.sample(repeticao, k=(qtde_filtrar_repetido if not somente_ausente else 0))
    
    jogo = sorted(jogo_ausente + jogo_repeticao)

    return jogo

def confere_resultado(id_tipo_jogo: int, apostas: str):
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo)
    premiacoes = tipo_jogo_repository.busca_dezenas_premiacao(id_tipo_jogo)
    lista_total = []
    
    aposta = apostas.split(',')
    lista_resultado = calcula_resultados(aposta, sorteios)
    for p in premiacoes:
        prm = p[0]
        acertos = [acerto for acerto in lista_resultado if acerto == prm]
        if (len(acertos)) > 0:
            lista_total.append({"Dezenas": prm, "Acertos": len(acertos)})
        else:
            lista_total.append({"Dezenas": prm, "Acertos": 0})
    
    return lista_total

def confere_resultado_por_concurso(id_tipo_jogo: int, apostas: str, nr_concurso: int):
    sorteios = sorteio_repository.busca_sorteio_por_concurso(id_tipo_jogo, nr_concurso, nr_concurso)
    premiacoes = tipo_jogo_repository.busca_dezenas_premiacao(id_tipo_jogo)
    lista_total = []
    
    aposta = apostas.split(',')
    lista_resultado = calcula_resultados(aposta, sorteios)
    for p in premiacoes:
        prm = p[0]
        acertos = [acerto for acerto in lista_resultado if acerto == prm]
        if (len(acertos)) > 0:
            lista_total.append(acertos[0])

    if not (lista_total):
        lista_total.append(lista_resultado[0])
    return lista_total
    
    
def calcula_resultados(aposta: list[str], sorteios: dict) -> list:
    resultados = []
    for s in sorteios:
        sorteioString = str(s["dezenas"])
        sorteio = sorteioString.split(',')
        resultado = [elemento for elemento in aposta if elemento in sorteio]
        resultados.append(len(resultado))
    return resultados

def valida_resultado(id_tipo_jogo: int,
                    apostas: str,
                    qtde_maxima_repetida_simulacao_resultado: int = None,
                    desvio_medio: float = None,
                    sempre_amarrar_jogos: bool = False,
                    id_usuario: int = 0,
                    valida_desvio_medio: bool = False,
                    ):

    resultado: bool = False
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
    premiacao = tipo_jogo_repository.busca_tipo_jogo_premiacao(id_tipo_jogo)
    sorteios = sorteio_repository.busca_sorteio_agrupado(id_tipo_jogo)
    ultimo_sorteio = sorteio_repository.busca_sorteio_por_concurso(id_tipo_jogo=id_tipo_jogo,
                                                                   nr_concurso_inicial=tipo_jogo.nr_concurso_max - 1,
                                                                   nr_concurso_final=tipo_jogo.nr_concurso_max - 1)
    aposta = apostas.split(',')
    lista_resultado = calcula_resultados(aposta, sorteios)
    lista_ultimo_resultado = calcula_resultados(aposta, ultimo_sorteio)
    lista_simulado = []

    # Valida se o jogo já foi sorteado com a qtde máxima por tipo de jogo
    acerto = [a for a in lista_resultado if a == tipo_jogo.qt_dezena_resultado]
    resultado = (len(acerto) > 0)
    # Verifica se já foi sorteado
    if (resultado):
        return True

    qtde_adicional_premio_min = 0
    if len(aposta) in (15, 16, 17):
        qtde_adicional_premio_min = 1
    elif len(aposta) == 18:
        qtde_adicional_premio_min = 2
    else:
        qtde_adicional_premio_min = 3

    # Valida se np último concurso a aposta já acerto mais do que o prêmio mínimo
    acerto_ultimo_resultado = [a for a in lista_ultimo_resultado if a == premiacao.qt_dezena_acerto + qtde_adicional_premio_min]
    if (len(acerto_ultimo_resultado) > 0):
        return True
    
    if (valida_desvio_medio):
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
            # if resultado:
            #     print(f'Aposta descartada: {aposta}')
        return resultado
    else:
        return False
def busca_sorteio_por_concurso(id_tipo_jogo: int, nr_concurso_inicial: int, nr_concurso_final: int) -> list[SorteioAgrupadoDTO]:
    sorteios = sorteio_repository.busca_sorteio_por_concurso(id_tipo_jogo, nr_concurso_inicial, nr_concurso_final)
    return [SorteioAgrupadoDTO(**sorteio) for sorteio in sorteios]

async def lista_sorteios_por_concurso (id_tipo_jogo: int, nr_concurso_inicial: int, nr_concurso_final: int) -> list[SorteioAgrupadoDTO]:
    return busca_sorteio_por_concurso(id_tipo_jogo, nr_concurso_inicial, nr_concurso_final)

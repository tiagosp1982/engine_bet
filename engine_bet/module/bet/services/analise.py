import pandas as pd
import numpy as np
from engine_bet.module.bet.dtos.calculate_dto import CalculateDTO
from engine_bet.module.bet.dtos.probability_dto import ProbabilityDTO
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDto
from engine_bet.module.bet.dtos.type_bet_dto import TypeBetDto
from engine_bet.module.bet.dtos.type_bet_structure import TypeBetStructureDTO
from engine_bet.module.bet.repositories.simulation_repository import simulation_repository
from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository
from engine_bet.module.bet.services.service import generate_new_bet, get_result_bet, raffle_by_id
from engine_bet.module.bet.services.simulation_service import insert

# Inicio - Parametros
id = 2
id_usuario = 1
qtde_aposta = 5
qtde_dezena_aposta = 7
somente_ausente = False
amarrar_jogos = False
# Fim - Parametros
grava_simulacao = True
tipo_jogo: TypeBetDto
tipo_jogo_estrutura: TypeBetStructureDTO
tipo_jogo_premiacao: TipoJogoPremiacaoDto
tipo_jogo = type_bet_repository.read_type_bet(id)
tipo_jogo_estrutura = type_bet_repository.read_type_bet_structure(id)
tipo_jogo_premiacao = type_bet_repository.read_type_bet_award(id)

qtde_maxima_dezenas_repetidas_entre_jogos = tipo_jogo_premiacao.qt_dezena_acerto
if not (amarrar_jogos):
    qtde_maxima_dezenas_repetidas_entre_jogos = qtde_maxima_dezenas_repetidas_entre_jogos - 1

if (qtde_dezena_aposta < tipo_jogo.qt_dezena_minima_aposta):
    print('Quantidade de dezenas da aposta é menor do que a quantidade mínima permitida.')
    exit()

if (qtde_dezena_aposta > tipo_jogo.qt_dezena_maxima_aposta):
    print('Quantidade de dezenas da aposta é maior do que a quantidade máxima permitida.')
    exit()

dados = raffle_by_id(id, False)
sorteios = RaffleDto.factoryRaffleOnly(dados)

numeros_por_sorteio = tipo_jogo.qt_dezena_resultado
numeros_total = len(tipo_jogo_estrutura)

n_sorteios = len(sorteios)
numeros_possiveis = list(range(1, numeros_total + 1))

filtrar_ausente = False
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
        
df = pd.DataFrame(sorteios, columns=[f"Num_{i+1}" for i in range(numeros_por_sorteio)])

# Unindo todas as colunas de sorteios em uma única série para contar a frequência de cada número
todos_numeros = pd.Series(df.values.ravel())
frequencia = todos_numeros.value_counts().sort_index().convert_dtypes(convert_integer=True)

# Calcula a medio do desvio padrão
estatisticas = []
for i, row in enumerate(sorteios):
    std_dev = np.std(row)
    estatisticas.append((std_dev))

desvio_total = sum(desvio for desvio in estatisticas)
media_desvio = (desvio_total / len(sorteios)).__round__(2)

# Análise de Probabilidade Empírica
total_sorteios = n_sorteios * numeros_por_sorteio
probabilidades_empiricas = (frequencia / total_sorteios).convert_dtypes(convert_integer=True)

probabilidades = []
list_probabilidade = (probabilidades_empiricas * 100).round(2).to_frame().T.to_dict()
for key in list_probabilidade:
    probabilidades.append(ProbabilityDTO(number=key, probability=list_probabilidade[key]['count']))

calculos = []
concurso_anterior = 0
qtde_ausencia_recente = 0
qtde_ausencia_total = 0
qtde_repeticao_recente = 0
qtde_repeticao_total = 0
index = 0
sorteado_ultimo_concurso: bool
finaliza_ausencia_recente: bool

for item in tipo_jogo_estrutura:
    finaliza_ausencia_recente = False
    sorteado = False
    qtde_ausencia_recente = 0
    qtde_ausencia_total = 0
    qtde_repeticao_recente = 0
    qtde_repeticao_total = 0
    index = 1

    for resultado in sorteios:
        # valida ausência
        if (not item.nr_estrutura_jogo in resultado):
            qtde_ausencia_total += 1
            if (not finaliza_ausencia_recente):
                qtde_ausencia_recente += 1
        else:
            finaliza_ausencia_recente = True

        # valida repetição
        if (item.nr_estrutura_jogo in resultado):
            qtde_repeticao_total += 1
            if (index > 0):
                qtde_repeticao_recente = index
                index += 1
        else:
            index = 0

    # prob = [res.probability for res in probabilidades if res.args[0] == item.nr_estrutura_jogo]
    for res in probabilidades: 
        if res.number == item.nr_estrutura_jogo:
            prob = res.probability

    calculos.append(
        CalculateDTO(
            NrDezena=item.nr_estrutura_jogo,
            QtAusenciaRecente=qtde_ausencia_recente,
            QtAusenciaTotal=qtde_ausencia_total,
            QtRepeticaoRecente=qtde_repeticao_recente,
            QtRepeticaoTotal=qtde_repeticao_total,
            VlProbabilidade=(100-(prob)-qtde_repeticao_recente)
            )
    )
    
qt_filtrar_ausente=(tipo_jogo.qt_dezena_minima_aposta-dezenas_filtrar)+qtde_adicional_ausente
qt_filtrar_repetido=(dezenas_filtrar+qtde_adicional_repetido)
simulacao = simulation_repository.read_last_simulation(id_tipo_jogo=id,
                                                        id_usuario=id_usuario,
                                                        nr_concurso_aposta=tipo_jogo.nr_concurso_max)

id_simulacao = (simulacao.id_simulacao if simulacao else 0)
tentativas = 0
for i in range(qtde_aposta):
    jogo_invalido = True
    id_simulacao += 1
    while jogo_invalido:
        tentativas += 1
        jogo = generate_new_bet(calculos=list(calculos),
                                qtde_filtrar_ausente=qt_filtrar_ausente,
                                qtde_filtrar_repetido=qt_filtrar_repetido,
                                dezenas_filtrar=dezenas_filtrar,
                                somente_ausente=somente_ausente
                                )
        
        jogo_invalido = get_result_bet(id_type_bet=id,
                                       bets=",".join(map(str, jogo)),
                                       valida_jogos=True,
                                       qtde_maxima_repetida_simulacao_resultado=qtde_maxima_dezenas_repetidas_entre_jogos,
                                       desvio_medio=media_desvio,
                                       sempre_amarrar_jogos=amarrar_jogos,
                                       id_usuario=id_usuario
                                       )
        if (jogo_invalido and qt_filtrar_ausente > 0 and tentativas >= 30):
            qt_filtrar_ausente -= 1
            qt_filtrar_repetido += 1
            dezenas_filtrar += 1
            tentativas = 0

    if (grava_simulacao):
        simulacao = insert(id_simulacao=id_simulacao,
                            id_usuario=id_usuario,
                            id_tipo_jogo=id,
                            nr_concurso=tipo_jogo.nr_concurso_max,
                            numeros_simulados=jogo)
    print(jogo)

    
            

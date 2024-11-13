import random
import pandas as pd
from engine_bet.module.bet.dtos.calculate_dto import CalculateDTO
from engine_bet.module.bet.dtos.probability_dto import ProbabilityDTO
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto
from engine_bet.module.bet.dtos.type_bet_dto import TypeBetDto
from engine_bet.module.bet.dtos.type_bet_structure import TypeBetStructureDTO
from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository
from engine_bet.module.bet.services.service import raffle_by_id


id = 1
qtde_dezena_jogo = 18
tipo_jogo_estrutura: TypeBetStructureDTO
tipo_jogo: TypeBetDto
tipo_jogo_estrutura = type_bet_repository.read_type_bet_structure(id)
tipo_jogo = type_bet_repository.read_type_bet(id)

dados = raffle_by_id(id, False)
sorteios = RaffleDto.factoryRaffleOnly(dados)

numeros_por_sorteio = tipo_jogo.qt_dezena_resultado
numeros_total = len(tipo_jogo_estrutura)

n_sorteios = len(sorteios)
numeros_possiveis = list(range(1, numeros_total + 1))

filtrar_ausente = False
dezenas_filtrar = 0
if ((numeros_total / 2) > tipo_jogo.qt_dezena_minima_aposta):
    filtrar_ausente = True

resultado_anterior = ""
total_repetido = 0
for s in sorteios:
    if (not resultado_anterior == ''):
        total_repetido += len(set(s) & set(resultado_anterior))
    resultado_anterior = s
dezenas_filtrar = int((total_repetido / n_sorteios).__round__(0))

qtde_adicional_ausente = 0
qtde_adicional_repetido = 0

if (qtde_adicional_numeros:= qtde_dezena_jogo - tipo_jogo.qt_dezena_minima_aposta):
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
print(calculos)
# ausente = list(filter(lambda c: c.QtAusenciaRecente > 0, calculos))
ausente = [c for c in calculos if c.QtAusenciaRecente > 0]
ausente = [a.NrDezena for a in ausente]
random.shuffle(ausente)

# repeticao = list(filter(lambda c: c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= dezenas_filtrar, calculos))
repeticao = [c for c in calculos if c.QtAusenciaRecente == 0 and c.QtRepeticaoRecente > 0 and c.QtRepeticaoRecente <= dezenas_filtrar]
repeticao = sorted(repeticao, key=lambda p: p.QtRepeticaoRecente and p.VlProbabilidade, reverse=True)
repeticao = [a.NrDezena for a in repeticao]
random.shuffle(repeticao)

if (filtrar_ausente):
    jogo_ausente = random.sample(ausente, k=(tipo_jogo.qt_dezena_minima_aposta-dezenas_filtrar)+qtde_adicional_ausente)
    jogo_repeticao = random.sample(repeticao, k=dezenas_filtrar+qtde_adicional_repetido)
else:
    # verificar
    jogo_ausente = random.sample(ausente, k=(tipo_jogo.qt_dezena_minima_aposta-dezenas_filtrar)+qtde_adicional_ausente)
    jogo_repeticao = random.sample(repeticao, k=dezenas_filtrar+qtde_adicional_repetido)

jogo = sorted(jogo_ausente + jogo_repeticao)
print(jogo)
    
            

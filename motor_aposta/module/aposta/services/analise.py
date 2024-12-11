import random
import pandas as pd
import numpy as np
from motor_aposta.module.aposta.dtos.calculo_dto import CalculoDTO
from motor_aposta.module.aposta.dtos.probabilidade_dto import ProbabilidadeDTO
from motor_aposta.module.aposta.dtos.sorteio_dto import SorteioDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_premiacao_dto import TipoJogoPremiacaoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.repositories.simulacao_repository import simulacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.services.service import generate_new_bet, get_result_bet, sorteio_by_id
from motor_aposta.module.aposta.services.simulacao_service import insert

# Inicio - Parametros
id = 1
id_usuario = 1
qtde_aposta = 1
qtde_dezena_aposta = 20
somente_ausente = False
amarrar_jogos = False
# Fim - Parametros
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

dados = sorteio_by_id(id, False)
sorteios = SorteioDTO.ConverterListaSorteio(dados)

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
lista_probabilidade = (probabilidades_empiricas * 100).round(2).to_frame().T.to_dict()
for key in lista_probabilidade:
    probabilidades.append(ProbabilidadeDTO(numero=key, probabilidade=lista_probabilidade[key]['count']))

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

    for res in probabilidades: 
        if res.numero == item.nr_estrutura_jogo:
            prob = res.probabilidade

    calculos.append(
        CalculoDTO(
            NrDezena=item.nr_estrutura_jogo,
            QtAusenciaRecente=qtde_ausencia_recente,
            QtAusenciaTotal=qtde_ausencia_total,
            QtRepeticaoRecente=qtde_repeticao_recente,
            QtRepeticaoTotal=qtde_repeticao_total,
            VlProbabilidade=(100-(prob)-qtde_repeticao_recente)
            )
    )

simulacao = simulacao_repository.busca_ultima_simulacao(id_tipo_jogo=id,
                                                        id_usuario=id_usuario,
                                                        nr_concurso_aposta=tipo_jogo.nr_concurso_max)

id_simulacao = (simulacao.id_simulacao if simulacao else 0)
tentativas = 0
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
        tentativas += 1
        jogo = generate_new_bet(calculos=list(calculos),
                                qtde_filtrar_ausente=qt_filtrar_ausente,
                                qtde_filtrar_repetido=qt_filtrar_repetido,
                                somente_ausente=somente_ausente
                                )
        
        jogo_invalido = get_result_bet(id_tipo_jogo=id,
                                       bets=",".join(map(str, jogo)),
                                       valida_jogos=True,
                                       qtde_maxima_repetida_simulacao_resultado=qtde_maxima_dezenas_repetidas_entre_jogos,
                                       desvio_medio=media_desvio,
                                       sempre_amarrar_jogos=amarrar_jogos,
                                       id_usuario=id_usuario
                                       )

    if (grava_simulacao):
        simulacao = insert(id_simulacao=id_simulacao,
                            id_usuario=id_usuario,
                            id_tipo_jogo=id,
                            nr_concurso=tipo_jogo.nr_concurso_max,
                            numeros_simulados=jogo)
    print(jogo)

    
            

import pandas as pd
from motor_aposta.module.aposta.dtos.calculo_dto import CalculoDTO
from motor_aposta.module.aposta.dtos.probabilidade_dto import ProbabilidadeDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.services.resultado_service import sorteio_by_id


async def calcular_dezenas(_id_tipo_jogo: int) -> dict:
    calculos = calcula_dezenas(_id_tipo_jogo)
    return calculos

def calcula_dezenas(_id_tipo_jogo: int) -> dict:
    tipo_jogo: TipoJogoDTO
    tipo_jogo_estrutura: TipoJogoEstruturaDTO
    calculos = []
    qtde_ausencia_recente = 0
    qtde_ausencia_total = 0
    qtde_repeticao_recente = 0
    qtde_repeticao_total = 0
    index = 0
    finaliza_ausencia_recente: bool
    
    # Informações do tipo de jogo
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(_id_tipo_jogo)
    tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(_id_tipo_jogo)
    
    # Informações do sorteio
    dados = sorteio_by_id(_id_tipo_jogo, False)
    sorteios = SorteioFactory.ConverterListaSorteio(dados)
    
    numeros_por_sorteio = tipo_jogo.qt_dezena_resultado
    df = pd.DataFrame(sorteios, columns=[f"Num_{i+1}" for i in range(numeros_por_sorteio)])

    # Unindo todas as colunas de sorteios em uma única série para contar a frequência de cada número
    todos_numeros = pd.Series(df.values.ravel())
    frequencia = todos_numeros.value_counts().sort_index().convert_dtypes(convert_integer=True)
    
    n_sorteios = len(sorteios)
    
    # Análise de Probabilidade Empírica
    total_sorteios = n_sorteios * numeros_por_sorteio
    probabilidades_empiricas = (frequencia / total_sorteios).convert_dtypes(convert_integer=True)

    probabilidades = []
    lista_probabilidade = (probabilidades_empiricas * 100).round(2).to_frame().T.to_dict()
    for key in lista_probabilidade:
        probabilidades.append(ProbabilidadeDTO(numero=key, probabilidade=lista_probabilidade[key]['count']))

    for item in tipo_jogo_estrutura:
        finaliza_ausencia_recente = False
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

    return calculos
from asyncio import as_completed
from concurrent.futures import ThreadPoolExecutor
import csv
from itertools import combinations
from motor_aposta.module.aposta.repositories.combinacao_repository import combinacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.services.combinacao_service import insere_combinacao


def insere_combinacao_csv():
    id = 1
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id)

    # gera as combinações de jogos por todas as qtdes disponível por tipo de jogo
    for i in range(tipo_jogo.qt_dezena_minima_aposta, tipo_jogo.qt_dezena_maxima_aposta + 1):
        # gera combinações
        
        nome_arquivo = f'C:\Tiago\combinacoes_lotofacil_{i}.csv'
        combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')

def gera_combinacao_csv():
    id = 1
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id)
    tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id)
    estrutura_jogo = []

    # obtem todos os números disponíveis por tipo de jogo
    for e in tipo_jogo_estrutura:
        estrutura_jogo.append(e.nr_estrutura_jogo)


    # gera as combinações de jogos por todas as qtdes disponível por tipo de jogo
    for i in range(tipo_jogo.qt_dezena_minima_aposta, tipo_jogo.qt_dezena_maxima_aposta + 1):
        # gera combinações
        id_combinacao = 0
        combinacoes = list(combinations(estrutura_jogo, i))
        nome_arquivo = f'C:\Tiago\combinacoes_lotofacil_{i}.csv'
        with open(nome_arquivo, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
                # Escreve registros simulados
            for combinacao in combinacoes:
                id_combinacao += 1
                writer.writerow([tipo_jogo.id_tipo_jogo, i, str(combinacao).replace('(','').replace(')',''), id_combinacao])

            combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')

def gera_new():
    # Etapa 1: Definir o grupo de 25 números
    grupo_25 = list(range(1, 26))  # Números de 1 a 25

    # Etapa 2: Gerar todas as combinações de 16 números
    combinacoes_16 = combinations(grupo_25, 16)

    # Opcional: Salvar as combinações em um arquivo
    with open("todas_combinacoes_16.txt", "w") as f:
        for comb in combinacoes_16:
            f.write(",".join(map(str, comb)) + "\n")

    print("Todas as combinações de 16 números foram geradas e salvas no arquivo 'todas_combinacoes_16.txt'.")

# gera_new()
# gera_combinacao_csv()
insere_combinacao_csv()
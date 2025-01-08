from concurrent.futures import ThreadPoolExecutor
import csv
from itertools import combinations
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.repositories.combinacao_repository import combinacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.services.combinacao_service import gera_combinacao_sorteio, valida_combinacao_improvavel


def insere_combinacao_csv(id: int):
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id)

    # gera as combinações de jogos por todas as qtdes disponível por tipo de jogo
    for i in range(tipo_jogo.qt_dezena_minima_aposta, tipo_jogo.qt_dezena_maxima_aposta + 1):
        # gera combinações
        
        nome_arquivo = f'C:\Tiago\combinacoes_lotofacil_{i}.csv'
        combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')
        
def insere_combinacao_avulsa_csv(nome_arquivo: str):
    combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')

def gera_combinacao_csv(id: int, qtde_dezena: int = 0, index: int = 0):
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id)
    tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id)
    estrutura_jogo = []

    # obtem todos os números disponíveis por tipo de jogo
    for e in tipo_jogo_estrutura:
        estrutura_jogo.append(e.nr_estrutura_jogo)

    if (qtde_dezena > 0):
        gera(qtde_dezena=qtde_dezena, tipo_jogo=tipo_jogo, estrutura_jogo=estrutura_jogo, index=index)
    else:
        # gera as combinações de jogos por todas as qtdes disponível por tipo de jogo
        for i in range(tipo_jogo.qt_dezena_minima_aposta, tipo_jogo.qt_dezena_maxima_aposta + 1):
            # gera combinações
            gera(qtde_dezena=i, tipo_jogo=tipo_jogo, estrutura_jogo=estrutura_jogo)
        
            
def gera(qtde_dezena: int, tipo_jogo: TipoJogoDTO, estrutura_jogo: list, index: int = 0):
    id_combinacao = 0
    count = 0
    if (index > 0):
        arquivo = int((index / 3000000) + 1)
    else:    
        arquivo = 1
    combinacoes = list(combinations(estrutura_jogo, qtde_dezena))
    nome_arquivo = f'{tipo_jogo.id_tipo_jogo}_{qtde_dezena}_{arquivo}.csv'
    csvfile = open(nome_arquivo, 'w', newline='')
    writer = csv.writer(csvfile)
    
    if (index > 0):    
        id_combinacao = index
        index += 1
        for i in range(len(combinacoes)):
            combinacao = combinacoes[index]
            count += 1
            id_combinacao += 1
            print(f'Combinação: {id_combinacao}')
            writer.writerow([tipo_jogo.id_tipo_jogo, qtde_dezena, str(combinacao).replace('(','').replace(')',''), id_combinacao, "N"])

            if (count == 3000000):
                count = 0
                arquivo += 1
                csvfile.close()
                combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')
                nome_arquivo = f'{tipo_jogo.id_tipo_jogo}_{qtde_dezena}_{arquivo}.csv'
                csvfile = open(nome_arquivo, 'w', newline='')
                writer = csv.writer(csvfile)
            i += 1
            index += 1
    else:
        for combinacao in combinacoes:
            count += 1
            id_combinacao += 1
            print(f'Combinação: {id_combinacao}')
            writer.writerow([tipo_jogo.id_tipo_jogo, qtde_dezena, str(combinacao).replace('(','').replace(')',''), id_combinacao, "N"])

            if (count == 3000000):
                count = 0
                arquivo += 1
                csvfile.close()
                combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')
                nome_arquivo = f'{tipo_jogo.id_tipo_jogo}_{qtde_dezena}_{arquivo}.csv'
                csvfile = open(nome_arquivo, 'w', newline='')
                writer = csv.writer(csvfile)

    csvfile.close()
    print('Inclusão dos dados')
    combinacao_repository.insere_lote_csv(nome_arquivo, 'combinacao')
    print('Dados inclusos na tabela de combinação')
    

def gera_new():
    # Etapa 1: Definir o grupo de 25 números
    grupo_60 = list(range(1, 61))  # Números de 1 a 25

    # Etapa 2: Gerar todas as combinações de 16 números
    combinacoes_60 = combinations(grupo_60, 7)

    # Opcional: Salvar as combinações em um arquivo
    with open("todas_combinacoes_60_com_7_mega.txt", "w") as f:
        for comb in combinacoes_60:
            f.write(",".join(map(str, comb)) + "\n")

    print("Todas as combinações de 7 números foram geradas e salvas no arquivo 'todas_combinacoes_60_com_7_mega.txt'.")

id = 1
qtde = 16
# valida_combinacao_improvavel(id, qtde)

# gera_combinacao_csv(id, qtde, 33000000)
# valida_combinacao_improvavel(id, qtde)
gera_combinacao_sorteio(id, qtde)
# insere_combinacao_csv()displa

# res = gera_combinacao_sorteio(1, 16)
# print(len(res))
# print(res)

# res = valida_combinacao_improvavel(1, 16)
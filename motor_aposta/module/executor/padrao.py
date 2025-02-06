import numpy as np
from collections import Counter

from motor_aposta.module.aposta.dtos.sorteio_dto import SorteioDTO
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory
from motor_aposta.module.aposta.services.resultado_service import sorteio_por_id

# Exemplo de base histórica com conjuntos de 7 números
id = 1
dados = sorteio_por_id(id, False, True)
historical_data = SorteioFactory.ConverterListaSorteio(dados)

# Função para identificar padrões básicos
def analyze_patterns(data):
    all_numbers = [num for row in data for num in row]
    
    # Frequência de cada número
    frequency = Counter(all_numbers)
    print("Frequência dos números:")
    for num, count in frequency.most_common():
        print(f"Número {num}: {count} vezes")
    
    # Média e desvio padrão de cada conjunto
    estatisticas = []
    print("\nEstatísticas dos conjuntos:")
    for i, row in enumerate(data):
        mean = np.mean(row)
        std_dev = np.std(row)
        estatisticas.append((mean, std_dev))
        print(f"Conjunto {i+1}: Média = {mean:.2f}, Desvio Padrão = {std_dev:.2f}")
    
    # Calcula média do valor médio dos jogos
    media = sum(media[0] for media in estatisticas)
    media = media / len(data)
    
    # Calcula média do desvio padrão
    desvio = sum(media[1] for media in estatisticas)
    desvio = desvio / len(data)
    
    # Identificação de números comuns entre os conjuntos
    common_numbers = set(data[0])
    for row in data[1:]:
        common_numbers.intersection_update(row)
    print("\nNúmeros comuns em todos os conjuntos:", common_numbers)
    
    # Identificação de sequências
    print("\nSequências detectadas:")
    for i, row in enumerate(data):
        sequences = []
        for j in range(len(row) - 1):
            if row[j] + 1 == row[j + 1]:
                sequences.append((row[j], row[j + 1]))
        print(f"Conjunto {i+1}: Sequências consecutivas: {sequences}")

# Executar análise
analyze_patterns(historical_data)

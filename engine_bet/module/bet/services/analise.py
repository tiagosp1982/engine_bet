import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.stats import chisquare

# print(plt.style.available)
# exit()

# Configurações de Estilo
plt.style.use('seaborn-v0_8-darkgrid')

# 1. Carregar Dados
# Exemplo: Vamos supor que os números sorteados vão de 1 a 60
# Se você tiver um CSV, use: df = pd.read_csv('historico_sorteios.csv')
# Aqui vamos simular uma base histórica para o exemplo
np.random.seed(42)
n_sorteios = 1000
numeros_por_sorteio = 6
numeros_possiveis = list(range(1, 61))  # Números de 1 a 60

# Simulando sorteios
sorteios = [np.random.choice(numeros_possiveis, size=numeros_por_sorteio, replace=False) for _ in range(n_sorteios)]
df = pd.DataFrame(sorteios, columns=[f"Num_{i+1}" for i in range(numeros_por_sorteio)])
print("Amostra dos Dados de Sorteios:")
print(df.head())

# 2. Análise Exploratória
# Unindo todas as colunas de sorteios em uma única série para contar a frequência de cada número
todos_numeros = pd.Series(df.values.ravel())
frequencia = todos_numeros.value_counts().sort_index()

# Estatísticas descritivas
print("\nEstatísticas Descritivas dos Sorteios:")
print(frequencia.describe())

# 3. Visualização da Frequência
plt.figure(figsize=(12, 6))
sns.barplot(x=frequencia.index, y=frequencia.values, palette='viridis')
plt.title('Frequência dos Números Sorteados')
plt.xlabel('Número')
plt.ylabel('Frequência')
plt.xticks(rotation=90)
plt.show()

# 4. Análise de Probabilidade Empírica
total_sorteios = n_sorteios * numeros_por_sorteio
probabilidades_empiricas = frequencia / total_sorteios
print("\nProbabilidade Empírica dos Números serem Sorteados (em %):")
print((probabilidades_empiricas * 100).round(2))

# 5. Validação Estatística
# Teste Qui-Quadrado para verificar se a distribuição é uniforme
frequencia_esperada = total_sorteios / len(numeros_possiveis)
chi2, p_value = chisquare(frequencia.values, [frequencia_esperada] * len(numeros_possiveis))

print("\nTeste Qui-Quadrado:")
print(f"Estatística Chi2: {chi2:.2f}")
print(f"P-valor: {p_value:.4f}")

if p_value > 0.05:
    print("Não há evidências suficientes para rejeitar a hipótese de distribuição uniforme (nível de 5%).")
else:
    print("Há evidências de que a distribuição dos números sorteados não é uniforme (nível de 5%).")

# 6. Visualização das Probabilidades Empíricas
plt.figure(figsize=(12, 6))
sns.barplot(x=probabilidades_empiricas.index, y=probabilidades_empiricas.values, palette='coolwarm')
plt.title('Probabilidade Empírica dos Números Sorteados')
plt.xlabel('Número')
plt.ylabel('Probabilidade Empírica')
plt.xticks(rotation=90)
plt.show()

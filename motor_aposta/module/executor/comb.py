from collections import Counter
from itertools import combinations
lista = [2,4,5,9,10,12,14,15,16,17,18,19,20,22,23,24,25]
total = list(combinations(lista,15))
print(len(total))
print(total)
exit()

# Conjunto fixo de 9 números
conjunto_fixo = [7, 8, 9, 12, 13, 14, 17, 18, 19]

# Histórico real ou exemplo
historico = [
    [7, 8, 12, 17],
    [8, 9, 12, 14, 17],
    [7, 9, 13, 17, 18, 19],
    [7, 8, 9, 12, 14],
    [8, 12, 13, 14],
    [7, 9, 13, 14, 18, 19],
    [12, 14, 17, 18, 19],
    [7, 8, 9, 13],
    [9, 12, 13, 17, 18, 19],
    [7, 8, 12, 13, 14],
]

# 1. Frequência de tamanhos dos conjuntos
tamanhos = [len(sorteio) for sorteio in historico]
frequencia_tamanhos = Counter(tamanhos)
print("📊 Frequência de quantidades sorteadas:")
for k in sorted(frequencia_tamanhos):
    print(f"{k} números: {frequencia_tamanhos[k]} vezes")

# 2. Média móvel da quantidade de números sorteados (últimos N sorteios)
janela = 5  # pode ajustar para 3, 5, 10 etc.
if len(tamanhos) >= janela:
    media_movel = sum(tamanhos[-janela:]) / janela
else:
    media_movel = sum(tamanhos) / len(tamanhos)

proxima_quantidade = round(media_movel)
print(f"\n📈 Média móvel (últimos {janela} sorteios): {media_movel:.2f}")
print(f"🔮 Previsão da quantidade de números no próximo sorteio: {proxima_quantidade}")

# 3. Frequência de cada número
frequencia_numeros = Counter()
for sorteio in historico:
    frequencia_numeros.update(sorteio)

print("\n📌 Frequência dos 9 números:")
for numero in conjunto_fixo:
    print(f"{numero}: {frequencia_numeros[numero]}")

# 4. Previsão dos próximos números
mais_frequentes = [numero for numero, _ in frequencia_numeros.most_common(proxima_quantidade)]
print(f"\n🎯 Próximo conjunto provável ({proxima_quantidade} números): {mais_frequentes}")

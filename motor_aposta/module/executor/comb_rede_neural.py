import numpy as np
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, LSTM
from sklearn.preprocessing import MinMaxScaler

# Conjunto fixo
conjunto_fixo = [7, 8, 9, 12, 13, 14, 17, 18, 19]

# Histórico de sorteios reais ou fictícios (pelo menos uns 15–20 para funcionar bem)
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
    [8, 9, 12, 17, 18],
    [9, 12, 13, 14, 19],
    [7, 9, 14, 17, 18, 19],
    [8, 12, 13, 18],
    [7, 9, 13, 14, 18],
]

# 1. Transformar sorteios em vetores binários
def sorteio_para_binario(sorteio):
    return [1 if n in sorteio else 0 for n in conjunto_fixo]

dados = np.array([sorteio_para_binario(s) for s in historico])

# 2. Criar sequências com janela deslizante
janela = 3
X = []
y = []
for i in range(janela, len(dados)):
    X.append(dados[i - janela:i])
    y.append(dados[i])

X = np.array(X)
y = np.array(y)

# 3. Construção do modelo (LSTM)
modelo = Sequential()
modelo.add(LSTM(64, activation='relu', input_shape=(X.shape[1], X.shape[2])))
modelo.add(Dense(32, activation='relu'))
modelo.add(Dense(len(conjunto_fixo), activation='sigmoid'))  # saída binária

modelo.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
modelo.fit(X, y, epochs=100, verbose=0)

# 4. Previsão do próximo sorteio
entrada = dados[-janela:]  # últimos sorteios
entrada = entrada.reshape((1, janela, len(conjunto_fixo)))
saida_binaria = modelo.predict(entrada)[0]

# 5. Limiares para definir presença (ajustável)
limiar = 0.5
proximo_sorteio = [conjunto_fixo[i] for i, v in enumerate(saida_binaria) if v > limiar]

print("🔮 Próximo conjunto previsto:", proximo_sorteio)

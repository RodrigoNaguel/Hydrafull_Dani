# HydraFuel Face

Watch face complementar do HydraFuel para Connect IQ 5.1 ou superior. O
mostrador usa apenas desenho vetorial e fontes do sistema, com layout relativo
para telas redondas MIP e AMOLED de 218 a 454 pixels.

## Recursos

- hora grande, data e arco de progresso da hidratação;
- três campos configuráveis, com calorias, temperatura e Body Battery por padrão;
- opções para passos, estresse, bateria, calorias e notificações;
- cafeína ativa recebida pela complication privada do HydraFuel;
- estilos Equilibrado, Foco em dados e Minimalista;
- cor de destaque configurável;
- editor nativo nos produtos recentes e App Settings nos demais;
- modo always-on AMOLED reduzido, com deslocamento contra burn-in;
- toque prolongado na hidratação para abrir o HydraFuel.

## Integração

Os aplicativos Connect IQ não compartilham `Application.Storage`. O HydraFuel
publica consumo/meta por `HYDRA` e cafeína ativa por `CAFFEINE`; esta watch face
assina as duas complications privadas. Ambos devem ser compilados e instalados
com a mesma developer key.

Depois de instalar os dois aplicativos, abra o HydraFuel uma vez para publicar
as complications. Até a primeira publicação, a watchface mostra `-- ml` e
`--%`; um `0 ml` exibido sempre foi publicado explicitamente pelo HydraFuel.

## Compilar

No diretório `watchface`:

```bash
monkeyc -f monkey.jungle -d fr165 \
  -o bin/HydraFuelFace-fr165.prg \
  -y ~/.Garmin/ConnectIQ/Keys/developer_key.der -w
```

Para testar a ponte no VS Code, use a configuração **Run Complication Apps** e
selecione a pasta raiz como publisher e `watchface` como subscriber.

## Testes

```bash
monkeyc -f monkey.jungle -d fr165 \
  -o bin/HydraFuelFaceTests-fr165.prg \
  -y ~/.Garmin/ConnectIQ/Keys/developer_key.der -t -w
monkeydo bin/HydraFuelFaceTests-fr165.prg fr165 -t
```

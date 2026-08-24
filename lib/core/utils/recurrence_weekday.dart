/// Conversão entre o dia da semana do seletor do formulário de evento e o
/// número ISO 8601 que o backend grava em `recurrence_days`.
///
/// O seletor exibe os chips na ordem domingo→sábado (dom, seg, ..., sáb) e
/// usa base 1: dom=1, seg=2, ..., sáb=7. O backend usa ISO 8601: 1=segunda,
/// ..., 7=domingo. A conversão acontece só nas bordas (leitura e request),
/// nunca no layout — a ordem visual dos chips não muda.
///
/// Uso: ao ler `recurrence_days` do backend use [isoToAppDay]; ao montar a
/// lista a enviar, use [appDayToIso].
int appDayToIso(int appDay) => appDay == 1 ? 7 : appDay - 1;

/// [iso] ISO 8601 (1=segunda..7=domingo) → dia no seletor (dom=1..sáb=7).
int isoToAppDay(int iso) => iso == 7 ? 1 : iso + 1;

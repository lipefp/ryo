// Chave publishable do Supabase (pública). Nunca colocar a secret aqui.
window.CAIXA_CONFIG = {
  supabaseUrl: "https://kxsmnjwnbkqecewpdtev.supabase.co",
  supabaseAnonKey: "sb_publishable_8oXjesRNulu7ro5MM80ChA_L-Jzhorn",

  // o id fica salvo nos lançamentos, não mudar
  cartoes: [
    { id: "santander", nome: "Cartão Santander", vencimento: 10 },
    { id: "nubank", nome: "Cartão Nubank" },
    { id: "emprestado", nome: "Cartão emprestado" }
  ],

  categorias: ["Alimentação", "Transporte", "Pessoal", "Lazer", "Compras", "Assinaturas", "Contas da casa", "Estudos", "Saúde", "Outros"],

  // importação: { contem: "ACADEMIA", categoria: "Saúde" }
  regras: [],

  atalhos: {
    gasto: [
      { t: "iFood", d: "iFood", c: "Alimentação" },
      { t: "Mercado", d: "Mercado", c: "Alimentação" },
      { t: "Transporte", d: "Transporte", c: "Transporte" }
    ],
    entrada: [
      { t: "Salário", d: "Salário" },
      { t: "13º salário", d: "13º salário" }
    ]
  }
};

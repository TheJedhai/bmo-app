/// Mapa de categorias (EN → PT-BR) para exibição.
///
/// Categorias não mapeadas são exibidas com o nome original capitalizado.
const Map<String, String> categoryLabelsPt = {
  'groceries': 'Supermercado',
  'restaurant': 'Restaurante',
  'restaurants': 'Restaurante',
  'transport': 'Transporte',
  'transportation': 'Transporte',
  'health': 'Saúde',
  'healthcare': 'Saúde',
  'education': 'Educação',
  'entertainment': 'Lazer',
  'leisure': 'Lazer',
  'shopping': 'Compras',
  'utilities': 'Contas',
  'housing': 'Moradia',
  'rent': 'Aluguel',
  'salary': 'Salário',
  'income': 'Receita',
  'investment': 'Investimentos',
  'investments': 'Investimentos',
  'transfer': 'Transferência',
  'transfers': 'Transferência',
  'subscription': 'Assinatura',
  'subscriptions': 'Assinatura',
  'travel': 'Viagem',
  'insurance': 'Seguro',
  'taxes': 'Impostos',
  'tax': 'Impostos',
  'clothing': 'Vestuário',
  'personal_care': 'Cuidados pessoais',
  'gifts': 'Presentes',
  'donations': 'Doações',
  'pets': 'Animais',
  'home': 'Casa',
  'electronics': 'Eletrônicos',
  'services': 'Serviços',
  'fees': 'Taxas',
  'interest': 'Juros',
  'cash': 'Dinheiro',
  'atm': 'Saque',
  'other': 'Outros',
  'uncategorized': 'Sem categoria',
};

String categoryDisplayName(String category) {
  return categoryLabelsPt[category] ??
      '${category[0].toUpperCase()}${category.substring(1)}';
}

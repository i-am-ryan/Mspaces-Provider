export const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
};

export const formatDate = (dateString: string): string => {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

export const formatDateShort = (dateString: string): string => {
  return new Date(dateString).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });
};

export const getDaysOverdue = (dueDate: string): number => {
  const due = new Date(dueDate);
  const today = new Date();
  const diffTime = today.getTime() - due.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return Math.max(0, diffDays);
};

export const getStatusColor = (status: 'paid' | 'pending' | 'overdue'): string => {
  switch (status) {
    case 'paid':
      return 'success';
    case 'pending':
      return 'warning';
    case 'overdue':
      return 'destructive';
    default:
      return 'secondary';
  }
};

export const getCategoryLabel = (category: string): string => {
  const labels: Record<string, string> = {
    maintenance: 'Maintenance',
    repairs: 'Repairs',
    utilities: 'Utilities',
    insurance: 'Insurance',
    property_tax: 'Property Tax',
    management: 'Management Fees',
    security_deposit: 'Security Deposit',
    refund: 'Refund',
    adjustment: 'Adjustment',
  };
  return labels[category] || category;
};

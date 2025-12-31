// Mock Data for Rental Management System

export interface Property {
  id: string;
  name: string;
  address: string;
  units: number;
  monthlyRent: number;
  type: 'apartment' | 'house' | 'condo' | 'commercial';
  status: 'occupied' | 'vacant' | 'partial';
  occupiedUnits: number;
  image: string;
}

export interface Tenant {
  id: string;
  name: string;
  email: string;
  phone: string;
  propertyId: string;
  unitNumber: string;
  leaseStart: string;
  leaseEnd: string;
  monthlyRent: number;
  securityDeposit: number;
  status: 'current' | 'expiring' | 'overdue';
  avatar?: string;
}

export interface InvoiceItem {
  description: string;
  amount: number;
}

export interface Invoice {
  id: string;
  tenantId: string;
  propertyId: string;
  amount: number;
  issueDate: string;
  dueDate: string;
  status: 'paid' | 'pending' | 'overdue';
  items: InvoiceItem[];
}

export interface Payment {
  id: string;
  invoiceId: string;
  tenantId: string;
  amount: number;
  paymentDate: string;
  paymentMethod: 'Bank Transfer' | 'Credit Card' | 'Cash' | 'Check';
  referenceNumber: string;
}

export interface Expense {
  id: string;
  propertyId: string;
  category: 'maintenance' | 'repairs' | 'utilities' | 'insurance' | 'property_tax' | 'management';
  vendor: string;
  amount: number;
  date: string;
  description: string;
  receipt?: string;
}

export interface CreditNote {
  id: string;
  tenantId: string;
  type: 'security_deposit' | 'refund' | 'adjustment';
  amount: number;
  date: string;
  description: string;
  status: 'available' | 'applied' | 'refunded';
}

// Properties
export const properties: Property[] = [
  {
    id: 'prop-1',
    name: 'Sunset Apartments',
    address: '123 Sunset Blvd, Los Angeles, CA 90028',
    units: 4,
    monthlyRent: 1500,
    type: 'apartment',
    status: 'occupied',
    occupiedUnits: 4,
    image: 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400'
  },
  {
    id: 'prop-2',
    name: 'Oak Street House',
    address: '456 Oak Street, San Francisco, CA 94102',
    units: 1,
    monthlyRent: 3200,
    type: 'house',
    status: 'occupied',
    occupiedUnits: 1,
    image: 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400'
  },
  {
    id: 'prop-3',
    name: 'Downtown Lofts',
    address: '789 Main St, San Diego, CA 92101',
    units: 6,
    monthlyRent: 1800,
    type: 'condo',
    status: 'partial',
    occupiedUnits: 4,
    image: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400'
  }
];

// Tenants
export const tenants: Tenant[] = [
  {
    id: 'tenant-1',
    name: 'John Smith',
    email: 'john.smith@email.com',
    phone: '(555) 123-4567',
    propertyId: 'prop-1',
    unitNumber: 'Unit 101',
    leaseStart: '2024-01-01',
    leaseEnd: '2025-12-31',
    monthlyRent: 1500,
    securityDeposit: 3000,
    status: 'current'
  },
  {
    id: 'tenant-2',
    name: 'Sarah Johnson',
    email: 'sarah.j@email.com',
    phone: '(555) 234-5678',
    propertyId: 'prop-1',
    unitNumber: 'Unit 102',
    leaseStart: '2024-03-01',
    leaseEnd: '2025-02-28',
    monthlyRent: 1500,
    securityDeposit: 3000,
    status: 'expiring'
  },
  {
    id: 'tenant-3',
    name: 'Michael Brown',
    email: 'mbrown@email.com',
    phone: '(555) 345-6789',
    propertyId: 'prop-1',
    unitNumber: 'Unit 103',
    leaseStart: '2024-06-01',
    leaseEnd: '2025-05-31',
    monthlyRent: 1500,
    securityDeposit: 3000,
    status: 'current'
  },
  {
    id: 'tenant-4',
    name: 'Emily Davis',
    email: 'emily.d@email.com',
    phone: '(555) 456-7890',
    propertyId: 'prop-1',
    unitNumber: 'Unit 104',
    leaseStart: '2024-02-01',
    leaseEnd: '2025-01-31',
    monthlyRent: 1500,
    securityDeposit: 3000,
    status: 'overdue'
  },
  {
    id: 'tenant-5',
    name: 'David Wilson',
    email: 'dwilson@email.com',
    phone: '(555) 567-8901',
    propertyId: 'prop-2',
    unitNumber: 'Main House',
    leaseStart: '2024-04-01',
    leaseEnd: '2025-03-31',
    monthlyRent: 3200,
    securityDeposit: 6400,
    status: 'current'
  },
  {
    id: 'tenant-6',
    name: 'Lisa Anderson',
    email: 'lisa.a@email.com',
    phone: '(555) 678-9012',
    propertyId: 'prop-3',
    unitNumber: 'Loft 301',
    leaseStart: '2024-05-01',
    leaseEnd: '2025-04-30',
    monthlyRent: 1800,
    securityDeposit: 3600,
    status: 'current'
  }
];

// Invoices
export const invoices: Invoice[] = [
  // January 2025
  { id: 'INV-2025-001', tenantId: 'tenant-1', propertyId: 'prop-1', amount: 1500, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'paid', items: [{ description: 'Monthly Rent - January 2025', amount: 1500 }] },
  { id: 'INV-2025-002', tenantId: 'tenant-2', propertyId: 'prop-1', amount: 1500, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'paid', items: [{ description: 'Monthly Rent - January 2025', amount: 1500 }] },
  { id: 'INV-2025-003', tenantId: 'tenant-3', propertyId: 'prop-1', amount: 1500, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'paid', items: [{ description: 'Monthly Rent - January 2025', amount: 1500 }] },
  { id: 'INV-2025-004', tenantId: 'tenant-4', propertyId: 'prop-1', amount: 1500, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'overdue', items: [{ description: 'Monthly Rent - January 2025', amount: 1500 }] },
  { id: 'INV-2025-005', tenantId: 'tenant-5', propertyId: 'prop-2', amount: 3200, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'paid', items: [{ description: 'Monthly Rent - January 2025', amount: 3200 }] },
  { id: 'INV-2025-006', tenantId: 'tenant-6', propertyId: 'prop-3', amount: 1800, issueDate: '2025-01-01', dueDate: '2025-01-05', status: 'paid', items: [{ description: 'Monthly Rent - January 2025', amount: 1800 }] },
  // December 2024
  { id: 'INV-2024-101', tenantId: 'tenant-1', propertyId: 'prop-1', amount: 1500, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 1500 }] },
  { id: 'INV-2024-102', tenantId: 'tenant-2', propertyId: 'prop-1', amount: 1500, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 1500 }] },
  { id: 'INV-2024-103', tenantId: 'tenant-3', propertyId: 'prop-1', amount: 1500, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 1500 }] },
  { id: 'INV-2024-104', tenantId: 'tenant-4', propertyId: 'prop-1', amount: 1650, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 1500 }, { description: 'Late Fee', amount: 150 }] },
  { id: 'INV-2024-105', tenantId: 'tenant-5', propertyId: 'prop-2', amount: 3200, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 3200 }] },
  { id: 'INV-2024-106', tenantId: 'tenant-6', propertyId: 'prop-3', amount: 1800, issueDate: '2024-12-01', dueDate: '2024-12-05', status: 'paid', items: [{ description: 'Monthly Rent - December 2024', amount: 1800 }] },
  // November 2024
  { id: 'INV-2024-091', tenantId: 'tenant-1', propertyId: 'prop-1', amount: 1500, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 1500 }] },
  { id: 'INV-2024-092', tenantId: 'tenant-2', propertyId: 'prop-1', amount: 1500, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 1500 }] },
  { id: 'INV-2024-093', tenantId: 'tenant-3', propertyId: 'prop-1', amount: 1500, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 1500 }] },
  { id: 'INV-2024-094', tenantId: 'tenant-4', propertyId: 'prop-1', amount: 1500, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 1500 }] },
  { id: 'INV-2024-095', tenantId: 'tenant-5', propertyId: 'prop-2', amount: 3200, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 3200 }] },
  { id: 'INV-2024-096', tenantId: 'tenant-6', propertyId: 'prop-3', amount: 1800, issueDate: '2024-11-01', dueDate: '2024-11-05', status: 'paid', items: [{ description: 'Monthly Rent - November 2024', amount: 1800 }] },
  // October 2024
  { id: 'INV-2024-081', tenantId: 'tenant-1', propertyId: 'prop-1', amount: 1500, issueDate: '2024-10-01', dueDate: '2024-10-05', status: 'paid', items: [{ description: 'Monthly Rent - October 2024', amount: 1500 }] },
  { id: 'INV-2024-082', tenantId: 'tenant-2', propertyId: 'prop-1', amount: 1500, issueDate: '2024-10-01', dueDate: '2024-10-05', status: 'paid', items: [{ description: 'Monthly Rent - October 2024', amount: 1500 }] },
  { id: 'INV-2024-083', tenantId: 'tenant-5', propertyId: 'prop-2', amount: 3200, issueDate: '2024-10-01', dueDate: '2024-10-05', status: 'paid', items: [{ description: 'Monthly Rent - October 2024', amount: 3200 }] },
];

// Payments
export const payments: Payment[] = [
  { id: 'PAY-001', invoiceId: 'INV-2025-001', tenantId: 'tenant-1', amount: 1500, paymentDate: '2025-01-03', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN123456' },
  { id: 'PAY-002', invoiceId: 'INV-2025-002', tenantId: 'tenant-2', amount: 1500, paymentDate: '2025-01-04', paymentMethod: 'Credit Card', referenceNumber: 'CC789012' },
  { id: 'PAY-003', invoiceId: 'INV-2025-003', tenantId: 'tenant-3', amount: 1500, paymentDate: '2025-01-02', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN345678' },
  { id: 'PAY-004', invoiceId: 'INV-2025-005', tenantId: 'tenant-5', amount: 3200, paymentDate: '2025-01-05', paymentMethod: 'Check', referenceNumber: 'CHK901234' },
  { id: 'PAY-005', invoiceId: 'INV-2025-006', tenantId: 'tenant-6', amount: 1800, paymentDate: '2025-01-03', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN567890' },
  { id: 'PAY-006', invoiceId: 'INV-2024-101', tenantId: 'tenant-1', amount: 1500, paymentDate: '2024-12-03', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN111111' },
  { id: 'PAY-007', invoiceId: 'INV-2024-102', tenantId: 'tenant-2', amount: 1500, paymentDate: '2024-12-04', paymentMethod: 'Credit Card', referenceNumber: 'CC222222' },
  { id: 'PAY-008', invoiceId: 'INV-2024-103', tenantId: 'tenant-3', amount: 1500, paymentDate: '2024-12-02', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN333333' },
  { id: 'PAY-009', invoiceId: 'INV-2024-104', tenantId: 'tenant-4', amount: 1650, paymentDate: '2024-12-10', paymentMethod: 'Cash', referenceNumber: 'CASH444444' },
  { id: 'PAY-010', invoiceId: 'INV-2024-105', tenantId: 'tenant-5', amount: 3200, paymentDate: '2024-12-05', paymentMethod: 'Check', referenceNumber: 'CHK555555' },
  { id: 'PAY-011', invoiceId: 'INV-2024-106', tenantId: 'tenant-6', amount: 1800, paymentDate: '2024-12-03', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN666666' },
  { id: 'PAY-012', invoiceId: 'INV-2024-091', tenantId: 'tenant-1', amount: 1500, paymentDate: '2024-11-03', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN777777' },
  { id: 'PAY-013', invoiceId: 'INV-2024-092', tenantId: 'tenant-2', amount: 1500, paymentDate: '2024-11-04', paymentMethod: 'Credit Card', referenceNumber: 'CC888888' },
  { id: 'PAY-014', invoiceId: 'INV-2024-093', tenantId: 'tenant-3', amount: 1500, paymentDate: '2024-11-02', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN999999' },
  { id: 'PAY-015', invoiceId: 'INV-2024-094', tenantId: 'tenant-4', amount: 1500, paymentDate: '2024-11-05', paymentMethod: 'Bank Transfer', referenceNumber: 'TXN101010' },
];

// Expenses
export const expenses: Expense[] = [
  { id: 'EXP-001', propertyId: 'prop-1', category: 'maintenance', vendor: 'ABC Plumbing', amount: 350, date: '2025-01-15', description: 'Fixed leaking faucet in Unit 102' },
  { id: 'EXP-002', propertyId: 'prop-1', category: 'utilities', vendor: 'City Water Dept', amount: 180, date: '2025-01-10', description: 'Common area water bill - January' },
  { id: 'EXP-003', propertyId: 'prop-2', category: 'repairs', vendor: 'Roof Masters Inc', amount: 1200, date: '2025-01-08', description: 'Roof repair after storm damage' },
  { id: 'EXP-004', propertyId: 'prop-3', category: 'insurance', vendor: 'State Farm', amount: 450, date: '2025-01-01', description: 'Monthly property insurance premium' },
  { id: 'EXP-005', propertyId: 'prop-1', category: 'property_tax', vendor: 'LA County', amount: 850, date: '2024-12-15', description: 'Quarterly property tax payment' },
  { id: 'EXP-006', propertyId: 'prop-2', category: 'management', vendor: 'PM Solutions', amount: 320, date: '2024-12-01', description: 'Property management fee - December' },
  { id: 'EXP-007', propertyId: 'prop-3', category: 'maintenance', vendor: 'Green Lawn Care', amount: 150, date: '2024-12-10', description: 'Landscaping and lawn maintenance' },
  { id: 'EXP-008', propertyId: 'prop-1', category: 'repairs', vendor: 'Electric Pro', amount: 275, date: '2024-11-20', description: 'Electrical outlet repairs Unit 104' },
  { id: 'EXP-009', propertyId: 'prop-2', category: 'utilities', vendor: 'PG&E', amount: 220, date: '2024-11-15', description: 'Gas and electric - common areas' },
  { id: 'EXP-010', propertyId: 'prop-3', category: 'maintenance', vendor: 'HVAC Experts', amount: 500, date: '2024-11-05', description: 'Annual HVAC system maintenance' },
];

// Credit Notes
export const creditNotes: CreditNote[] = [
  { id: 'CN-001', tenantId: 'tenant-1', type: 'security_deposit', amount: 3000, date: '2024-01-01', description: 'Security deposit received', status: 'available' },
  { id: 'CN-002', tenantId: 'tenant-2', type: 'adjustment', amount: 75, date: '2024-12-15', description: 'Rent overcharge correction', status: 'applied' },
  { id: 'CN-003', tenantId: 'tenant-3', type: 'refund', amount: 150, date: '2024-11-20', description: 'Overpayment refund pending', status: 'available' },
  { id: 'CN-004', tenantId: 'tenant-5', type: 'security_deposit', amount: 6400, date: '2024-04-01', description: 'Security deposit received', status: 'available' },
  { id: 'CN-005', tenantId: 'tenant-6', type: 'adjustment', amount: 50, date: '2024-10-10', description: 'Utility bill adjustment', status: 'applied' },
];

// Helper functions
export const getPropertyById = (id: string) => properties.find(p => p.id === id);
export const getTenantById = (id: string) => tenants.find(t => t.id === id);
export const getInvoicesByTenant = (tenantId: string) => invoices.filter(i => i.tenantId === tenantId);
export const getPaymentsByTenant = (tenantId: string) => payments.filter(p => p.tenantId === tenantId);
export const getCreditsByTenant = (tenantId: string) => creditNotes.filter(c => c.tenantId === tenantId);
export const getExpensesByProperty = (propertyId: string) => expenses.filter(e => e.propertyId === propertyId);

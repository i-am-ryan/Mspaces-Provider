import { useMemo } from "react";
import { useAuth } from "@/context/AuthContext";
import { KpiCard } from "@/components/ui/kpi-card";
import { StatusBadge } from "@/components/ui/status-badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  invoices,
  payments,
  creditNotes,
  getPropertyById,
  getTenantById,
} from "@/data/mockData";
import { formatCurrency, formatDate, getDaysOverdue } from "@/utils/formatters";
import { DollarSign, CreditCard, AlertCircle, Gift, Download, FileText, Eye } from "lucide-react";

export function TenantDashboard() {
  const { user } = useAuth();

  // Get tenant's data
  const tenantInvoices = useMemo(() => 
    invoices.filter(i => i.tenantId === user?.id), 
    [user?.id]
  );
  
  const tenantPayments = useMemo(() => 
    payments.filter(p => p.tenantId === user?.id),
    [user?.id]
  );

  const tenantCredits = useMemo(() =>
    creditNotes.filter(c => c.tenantId === user?.id && c.status === 'available'),
    [user?.id]
  );

  // Calculate KPIs
  const currentMonthDue = useMemo(() => {
    const pending = tenantInvoices.find(i => i.status === 'pending' || i.status === 'overdue');
    return pending?.amount || 0;
  }, [tenantInvoices]);

  const dueDate = useMemo(() => {
    const pending = tenantInvoices.find(i => i.status === 'pending' || i.status === 'overdue');
    return pending?.dueDate;
  }, [tenantInvoices]);

  const totalPaidThisYear = useMemo(() => {
    return tenantPayments
      .filter(p => p.paymentDate.startsWith('2025'))
      .reduce((sum, p) => sum + p.amount, 0);
  }, [tenantPayments]);

  const availableCredits = useMemo(() => {
    return tenantCredits.reduce((sum, c) => sum + c.amount, 0);
  }, [tenantCredits]);

  const overdueAmount = useMemo(() => {
    return tenantInvoices
      .filter(i => i.status === 'overdue')
      .reduce((sum, i) => sum + i.amount, 0);
  }, [tenantInvoices]);

  // Recent payments
  const recentPayments = useMemo(() => {
    return [...tenantPayments]
      .sort((a, b) => new Date(b.paymentDate).getTime() - new Date(a.paymentDate).getTime())
      .slice(0, 5);
  }, [tenantPayments]);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-foreground">Welcome back, {user?.name?.split(' ')[0]}!</h1>
        <p className="text-muted-foreground">Here's your rental summary</p>
      </div>

      {/* KPI Cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          title="Current Month Due"
          value={formatCurrency(currentMonthDue)}
          subtitle={dueDate ? `Due ${formatDate(dueDate)}` : "All paid"}
          icon={DollarSign}
          variant={currentMonthDue > 0 ? "warning" : "success"}
        />
        <KpiCard
          title="Total Paid This Year"
          value={formatCurrency(totalPaidThisYear)}
          subtitle="2025 payments"
          icon={CreditCard}
        />
        <KpiCard
          title="Available Credits"
          value={formatCurrency(availableCredits)}
          subtitle={`${tenantCredits.length} credit notes`}
          icon={Gift}
          variant={availableCredits > 0 ? "primary" : "default"}
        />
        <KpiCard
          title="Overdue Amount"
          value={formatCurrency(overdueAmount)}
          subtitle={overdueAmount > 0 ? "Please pay ASAP" : "No overdue payments"}
          icon={AlertCircle}
          variant={overdueAmount > 0 ? "destructive" : "success"}
        />
      </div>

      {/* Quick Actions & Recent Payments */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Quick Actions */}
        <Card className="shadow-card">
          <CardHeader>
            <CardTitle className="text-lg">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button className="w-full justify-start" variant="outline">
              <Download className="mr-2 h-4 w-4" />
              Download Latest Invoice
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <FileText className="mr-2 h-4 w-4" />
              Download Account Statement
            </Button>
            <Button className="w-full justify-start" variant="outline">
              <Eye className="mr-2 h-4 w-4" />
              View All Invoices
            </Button>
          </CardContent>
        </Card>

        {/* Recent Payments */}
        <Card className="shadow-card lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">Payment History</CardTitle>
            <Button variant="ghost" size="sm">View all</Button>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Invoice #</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>Method</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentPayments.map((payment) => {
                  const invoice = invoices.find(i => i.id === payment.invoiceId);
                  return (
                    <TableRow key={payment.id}>
                      <TableCell className="font-medium">
                        {formatDate(payment.paymentDate)}
                      </TableCell>
                      <TableCell>{payment.invoiceId}</TableCell>
                      <TableCell>{formatCurrency(payment.amount)}</TableCell>
                      <TableCell>{payment.paymentMethod}</TableCell>
                      <TableCell>
                        <StatusBadge variant="paid">Paid</StatusBadge>
                      </TableCell>
                    </TableRow>
                  );
                })}
                {recentPayments.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center text-muted-foreground">
                      No payment history yet
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

import { useMemo } from "react";
import { KpiCard } from "@/components/ui/kpi-card";
import { StatusBadge } from "@/components/ui/status-badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import {
  properties,
  tenants,
  invoices,
  payments,
  expenses,
  getTenantById,
  getPropertyById,
} from "@/data/mockData";
import { formatCurrency, formatDate, getDaysOverdue } from "@/utils/formatters";
import {
  DollarSign,
  TrendingUp,
  AlertTriangle,
  Wallet,
  Send,
  Eye,
} from "lucide-react";

export function LandlordDashboard() {
  // Calculate KPIs
  const monthlyIncome = useMemo(() => {
    return payments
      .filter(p => p.paymentDate.startsWith('2025-01'))
      .reduce((sum, p) => sum + p.amount, 0);
  }, []);

  const lastMonthIncome = useMemo(() => {
    return payments
      .filter(p => p.paymentDate.startsWith('2024-12'))
      .reduce((sum, p) => sum + p.amount, 0);
  }, []);

  const incomeChange = lastMonthIncome > 0 
    ? Math.round(((monthlyIncome - lastMonthIncome) / lastMonthIncome) * 100)
    : 0;

  const totalExpenses = useMemo(() => {
    return expenses
      .filter(e => e.date.startsWith('2025-01'))
      .reduce((sum, e) => sum + e.amount, 0);
  }, []);

  const accountsReceivable = useMemo(() => {
    return invoices
      .filter(i => i.status === 'pending' || i.status === 'overdue')
      .reduce((sum, i) => sum + i.amount, 0);
  }, []);

  const workingCapital = monthlyIncome - totalExpenses;

  // Charts data
  const incomeVsExpenses = [
    { month: 'Aug', income: 9500, expenses: 1800 },
    { month: 'Sep', income: 10000, expenses: 2100 },
    { month: 'Oct', income: 9200, expenses: 1500 },
    { month: 'Nov', income: 10500, expenses: 2200 },
    { month: 'Dec', income: 11150, expenses: 1820 },
    { month: 'Jan', income: monthlyIncome, expenses: totalExpenses },
  ];

  const collectionRate = useMemo(() => {
    const total = invoices.filter(i => i.issueDate.startsWith('2025-01')).length;
    const paid = invoices.filter(i => i.issueDate.startsWith('2025-01') && i.status === 'paid').length;
    return [
      { name: 'Paid', value: paid, color: 'hsl(160, 84%, 39%)' },
      { name: 'Outstanding', value: total - paid, color: 'hsl(38, 92%, 50%)' },
    ];
  }, []);

  // Recent payments
  const recentPayments = useMemo(() => {
    return [...payments]
      .sort((a, b) => new Date(b.paymentDate).getTime() - new Date(a.paymentDate).getTime())
      .slice(0, 8);
  }, []);

  // Outstanding invoices
  const outstandingInvoices = useMemo(() => {
    return invoices
      .filter(i => i.status === 'pending' || i.status === 'overdue')
      .map(i => ({
        ...i,
        daysOverdue: getDaysOverdue(i.dueDate),
      }))
      .sort((a, b) => b.daysOverdue - a.daysOverdue);
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-foreground">Dashboard</h1>
        <p className="text-muted-foreground">Overview of your rental business</p>
      </div>

      {/* KPI Cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          title="Monthly Rental Income"
          value={formatCurrency(monthlyIncome)}
          icon={DollarSign}
          trend={{ value: Math.abs(incomeChange), isPositive: incomeChange >= 0 }}
          variant="primary"
        />
        <KpiCard
          title="Total Expenses"
          value={formatCurrency(totalExpenses)}
          subtitle="This month"
          icon={TrendingUp}
        />
        <KpiCard
          title="Accounts Receivable"
          value={formatCurrency(accountsReceivable)}
          subtitle="Outstanding rent"
          icon={AlertTriangle}
          variant={accountsReceivable > 0 ? "warning" : "success"}
        />
        <KpiCard
          title="Working Capital"
          value={formatCurrency(workingCapital)}
          subtitle="Income - Expenses"
          icon={Wallet}
          variant={workingCapital > 0 ? "success" : "destructive"}
        />
      </div>

      {/* Charts */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Income vs Expenses */}
        <Card className="shadow-card">
          <CardHeader>
            <CardTitle className="text-lg">Income vs Expenses</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={incomeVsExpenses}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                  <XAxis dataKey="month" className="text-xs" />
                  <YAxis className="text-xs" />
                  <Tooltip 
                    formatter={(value: number) => formatCurrency(value)}
                    contentStyle={{ 
                      backgroundColor: 'hsl(var(--card))',
                      border: '1px solid hsl(var(--border))',
                      borderRadius: '8px'
                    }}
                  />
                  <Bar dataKey="income" fill="hsl(var(--chart-2))" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="expenses" fill="hsl(var(--chart-4))" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-4 flex items-center justify-center gap-6 text-sm">
              <div className="flex items-center gap-2">
                <div className="h-3 w-3 rounded-full bg-success" />
                <span className="text-muted-foreground">Income</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="h-3 w-3 rounded-full bg-destructive" />
                <span className="text-muted-foreground">Expenses</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Collection Rate */}
        <Card className="shadow-card">
          <CardHeader>
            <CardTitle className="text-lg">Collection Rate - January 2025</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={collectionRate}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    paddingAngle={5}
                    dataKey="value"
                    label={({ name, value }) => `${name}: ${value}`}
                  >
                    {collectionRate.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-4 flex items-center justify-center gap-6 text-sm">
              {collectionRate.map((item, i) => (
                <div key={i} className="flex items-center gap-2">
                  <div className="h-3 w-3 rounded-full" style={{ backgroundColor: item.color }} />
                  <span className="text-muted-foreground">{item.name}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Tables */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Recent Payments */}
        <Card className="shadow-card">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">Recent Payments</CardTitle>
            <Button variant="ghost" size="sm">View all</Button>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Tenant</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>Method</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentPayments.slice(0, 6).map((payment) => {
                  const tenant = getTenantById(payment.tenantId);
                  return (
                    <TableRow key={payment.id}>
                      <TableCell>{formatDate(payment.paymentDate)}</TableCell>
                      <TableCell>{tenant?.name}</TableCell>
                      <TableCell className="font-medium text-success">
                        {formatCurrency(payment.amount)}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {payment.paymentMethod}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        {/* Outstanding Invoices */}
        <Card className="shadow-card">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">Outstanding Invoices</CardTitle>
            <Button variant="ghost" size="sm">View all</Button>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Tenant</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>Days Overdue</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {outstandingInvoices.slice(0, 6).map((invoice) => {
                  const tenant = getTenantById(invoice.tenantId);
                  return (
                    <TableRow key={invoice.id} className={invoice.daysOverdue > 30 ? "bg-destructive/5" : ""}>
                      <TableCell>{tenant?.name}</TableCell>
                      <TableCell className="font-medium">
                        {formatCurrency(invoice.amount)}
                      </TableCell>
                      <TableCell>
                        <StatusBadge variant={invoice.daysOverdue > 0 ? "overdue" : "pending"}>
                          {invoice.daysOverdue > 0 ? `${invoice.daysOverdue} days` : "Due soon"}
                        </StatusBadge>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-1">
                          <Button variant="ghost" size="icon">
                            <Eye className="h-4 w-4" />
                          </Button>
                          <Button variant="ghost" size="icon">
                            <Send className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
                {outstandingInvoices.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={4} className="text-center text-muted-foreground py-8">
                      All invoices are paid! 🎉
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

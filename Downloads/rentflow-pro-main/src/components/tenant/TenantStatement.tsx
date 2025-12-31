import { useMemo } from "react";
import { useAuth } from "@/context/AuthContext";
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
import { invoices, payments, creditNotes } from "@/data/mockData";
import { formatCurrency, formatDate } from "@/utils/formatters";
import { Download, FileText } from "lucide-react";

type Transaction = {
  id: string;
  date: string;
  type: 'invoice' | 'payment' | 'credit';
  description: string;
  debit: number;
  credit: number;
};

export function TenantStatement() {
  const { user } = useAuth();

  // Combine all transactions
  const transactions = useMemo(() => {
    const allTransactions: Transaction[] = [];

    // Add invoices (debits)
    invoices
      .filter(i => i.tenantId === user?.id)
      .forEach(invoice => {
        allTransactions.push({
          id: invoice.id,
          date: invoice.issueDate,
          type: 'invoice',
          description: `Invoice ${invoice.id}`,
          debit: invoice.amount,
          credit: 0,
        });
      });

    // Add payments (credits)
    payments
      .filter(p => p.tenantId === user?.id)
      .forEach(payment => {
        allTransactions.push({
          id: payment.id,
          date: payment.paymentDate,
          type: 'payment',
          description: `Payment - ${payment.paymentMethod}`,
          debit: 0,
          credit: payment.amount,
        });
      });

    // Sort by date
    return allTransactions.sort((a, b) => 
      new Date(a.date).getTime() - new Date(b.date).getTime()
    );
  }, [user?.id]);

  // Calculate running balance
  const transactionsWithBalance = useMemo(() => {
    let balance = 0;
    return transactions.map(t => {
      balance = balance + t.debit - t.credit;
      return { ...t, balance };
    });
  }, [transactions]);

  // Summary calculations
  const summary = useMemo(() => {
    const totalCharges = transactions.reduce((sum, t) => sum + t.debit, 0);
    const totalPayments = transactions.reduce((sum, t) => sum + t.credit, 0);
    return {
      openingBalance: 0,
      totalCharges,
      totalPayments,
      closingBalance: totalCharges - totalPayments,
    };
  }, [transactions]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Account Statement</h1>
          <p className="text-muted-foreground">Complete transaction history</p>
        </div>
        <Button>
          <Download className="mr-2 h-4 w-4" />
          Download PDF Statement
        </Button>
      </div>

      {/* Summary */}
      <div className="grid gap-4 sm:grid-cols-4">
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Opening Balance</div>
            <div className="text-2xl font-bold">{formatCurrency(summary.openingBalance)}</div>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Total Charges</div>
            <div className="text-2xl font-bold text-destructive">
              +{formatCurrency(summary.totalCharges)}
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Total Payments</div>
            <div className="text-2xl font-bold text-success">
              -{formatCurrency(summary.totalPayments)}
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-card bg-primary text-primary-foreground">
          <CardContent className="pt-6">
            <div className="text-sm opacity-90">Closing Balance</div>
            <div className="text-2xl font-bold">{formatCurrency(summary.closingBalance)}</div>
          </CardContent>
        </Card>
      </div>

      {/* Transactions Table */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg">Transaction History</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Description</TableHead>
                <TableHead className="text-right">Debit</TableHead>
                <TableHead className="text-right">Credit</TableHead>
                <TableHead className="text-right">Balance</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {transactionsWithBalance.map((t) => (
                <TableRow key={t.id}>
                  <TableCell className="font-medium">
                    {formatDate(t.date)}
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <div className={`h-2 w-2 rounded-full ${
                        t.type === 'invoice' ? 'bg-warning' : 'bg-success'
                      }`} />
                      {t.description}
                    </div>
                  </TableCell>
                  <TableCell className="text-right text-destructive">
                    {t.debit > 0 ? formatCurrency(t.debit) : '-'}
                  </TableCell>
                  <TableCell className="text-right text-success">
                    {t.credit > 0 ? formatCurrency(t.credit) : '-'}
                  </TableCell>
                  <TableCell className="text-right font-medium">
                    {formatCurrency(t.balance)}
                  </TableCell>
                </TableRow>
              ))}
              {transactionsWithBalance.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} className="text-center text-muted-foreground py-8">
                    <FileText className="mx-auto h-12 w-12 text-muted-foreground/50 mb-2" />
                    No transactions yet
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

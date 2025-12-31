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
import { payments, invoices } from "@/data/mockData";
import { formatCurrency, formatDate } from "@/utils/formatters";
import { Download, Receipt } from "lucide-react";

export function TenantPayments() {
  const { user } = useAuth();

  const tenantPayments = useMemo(() => {
    return payments
      .filter(p => p.tenantId === user?.id)
      .sort((a, b) => new Date(b.paymentDate).getTime() - new Date(a.paymentDate).getTime());
  }, [user?.id]);

  const totalPaid = useMemo(() => {
    return tenantPayments.reduce((sum, p) => sum + p.amount, 0);
  }, [tenantPayments]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Payment History</h1>
          <p className="text-muted-foreground">View all your payment transactions</p>
        </div>
        <Button variant="outline">
          <Download className="mr-2 h-4 w-4" />
          Export to CSV
        </Button>
      </div>

      {/* Summary */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{tenantPayments.length}</div>
            <p className="text-sm text-muted-foreground">Total Payments</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-success">{formatCurrency(totalPaid)}</div>
            <p className="text-sm text-muted-foreground">Total Amount Paid</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">
              {tenantPayments[0] ? formatDate(tenantPayments[0].paymentDate) : "-"}
            </div>
            <p className="text-sm text-muted-foreground">Last Payment</p>
          </CardContent>
        </Card>
      </div>

      {/* Payments Table */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg">All Payments</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Invoice #</TableHead>
                <TableHead>Amount Paid</TableHead>
                <TableHead>Payment Method</TableHead>
                <TableHead>Reference #</TableHead>
                <TableHead className="text-right">Receipt</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {tenantPayments.map((payment) => (
                <TableRow key={payment.id}>
                  <TableCell className="font-medium">
                    {formatDate(payment.paymentDate)}
                  </TableCell>
                  <TableCell>{payment.invoiceId}</TableCell>
                  <TableCell className="font-medium text-success">
                    {formatCurrency(payment.amount)}
                  </TableCell>
                  <TableCell>{payment.paymentMethod}</TableCell>
                  <TableCell className="font-mono text-sm">
                    {payment.referenceNumber}
                  </TableCell>
                  <TableCell className="text-right">
                    <Button variant="ghost" size="sm">
                      <Download className="mr-2 h-4 w-4" />
                      Receipt
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {tenantPayments.length === 0 && (
                <TableRow>
                  <TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                    <Receipt className="mx-auto h-12 w-12 text-muted-foreground/50 mb-2" />
                    No payment history yet
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

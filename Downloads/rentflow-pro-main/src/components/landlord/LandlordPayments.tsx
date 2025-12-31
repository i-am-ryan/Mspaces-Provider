import { useState, useMemo } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { payments, invoices, tenants, getTenantById, getPropertyById } from "@/data/mockData";
import { formatCurrency, formatDate } from "@/utils/formatters";
import { Plus, Download, DollarSign } from "lucide-react";

export function LandlordPayments() {
  const [isAddOpen, setIsAddOpen] = useState(false);

  const sortedPayments = useMemo(() => {
    return [...payments].sort((a, b) => 
      new Date(b.paymentDate).getTime() - new Date(a.paymentDate).getTime()
    );
  }, []);

  const totalCollected = useMemo(() => {
    return payments.reduce((sum, p) => sum + p.amount, 0);
  }, []);

  const thisMonthPayments = useMemo(() => {
    return payments.filter(p => p.paymentDate.startsWith('2025-01'))
      .reduce((sum, p) => sum + p.amount, 0);
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Payments</h1>
          <p className="text-muted-foreground">Track all rent payments</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline">
            <Download className="mr-2 h-4 w-4" />
            Export CSV
          </Button>
          <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" />
                Record Payment
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Record Payment</DialogTitle>
              </DialogHeader>
              <form className="space-y-4">
                <div className="space-y-2">
                  <Label>Tenant</Label>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Select tenant" />
                    </SelectTrigger>
                    <SelectContent>
                      {tenants.map(t => (
                        <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Invoice</Label>
                  <Select>
                    <SelectTrigger>
                      <SelectValue placeholder="Select invoice" />
                    </SelectTrigger>
                    <SelectContent>
                      {invoices.filter(i => i.status !== 'paid').map(i => (
                        <SelectItem key={i.id} value={i.id}>
                          {i.id} - {formatCurrency(i.amount)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="amount">Amount</Label>
                    <Input id="amount" type="number" placeholder="1500" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="date">Payment Date</Label>
                    <Input id="date" type="date" />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Payment Method</Label>
                    <Select>
                      <SelectTrigger>
                        <SelectValue placeholder="Method" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="bank">Bank Transfer</SelectItem>
                        <SelectItem value="card">Credit Card</SelectItem>
                        <SelectItem value="cash">Cash</SelectItem>
                        <SelectItem value="check">Check</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="ref">Reference #</Label>
                    <Input id="ref" placeholder="TXN123456" />
                  </div>
                </div>
                <div className="flex justify-end gap-3 pt-4">
                  <Button type="button" variant="outline" onClick={() => setIsAddOpen(false)}>
                    Cancel
                  </Button>
                  <Button type="submit" onClick={() => setIsAddOpen(false)}>
                    Record Payment
                  </Button>
                </div>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="rounded-lg bg-success/10 p-3">
                <DollarSign className="h-6 w-6 text-success" />
              </div>
              <div>
                <div className="text-2xl font-bold text-success">
                  {formatCurrency(totalCollected)}
                </div>
                <p className="text-sm text-muted-foreground">Total Collected</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{formatCurrency(thisMonthPayments)}</div>
            <p className="text-sm text-muted-foreground">This Month</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{payments.length}</div>
            <p className="text-sm text-muted-foreground">Total Transactions</p>
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
                <TableHead>Tenant</TableHead>
                <TableHead>Property</TableHead>
                <TableHead>Invoice #</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Method</TableHead>
                <TableHead>Reference #</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {sortedPayments.map((payment) => {
                const tenant = getTenantById(payment.tenantId);
                const invoice = invoices.find(i => i.id === payment.invoiceId);
                const property = invoice ? getPropertyById(invoice.propertyId) : null;

                return (
                  <TableRow key={payment.id}>
                    <TableCell className="font-medium">
                      {formatDate(payment.paymentDate)}
                    </TableCell>
                    <TableCell>{tenant?.name}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {property?.name}
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {payment.invoiceId}
                    </TableCell>
                    <TableCell className="font-medium text-success">
                      {formatCurrency(payment.amount)}
                    </TableCell>
                    <TableCell>{payment.paymentMethod}</TableCell>
                    <TableCell className="font-mono text-sm text-muted-foreground">
                      {payment.referenceNumber}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

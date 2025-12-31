import { useState, useMemo } from "react";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { invoices, getTenantById, getPropertyById } from "@/data/mockData";
import { formatCurrency, formatDate, getDaysOverdue } from "@/utils/formatters";
import { Plus, Download, Eye, Send, Check, FileText } from "lucide-react";

export function LandlordInvoices() {
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [propertyFilter, setPropertyFilter] = useState<string>("all");

  const filteredInvoices = useMemo(() => {
    let filtered = [...invoices];
    if (statusFilter !== "all") {
      filtered = filtered.filter(i => i.status === statusFilter);
    }
    if (propertyFilter !== "all") {
      filtered = filtered.filter(i => i.propertyId === propertyFilter);
    }
    return filtered.sort((a, b) => 
      new Date(b.issueDate).getTime() - new Date(a.issueDate).getTime()
    );
  }, [statusFilter, propertyFilter]);

  const stats = useMemo(() => ({
    total: invoices.length,
    paid: invoices.filter(i => i.status === 'paid').length,
    pending: invoices.filter(i => i.status === 'pending').length,
    overdue: invoices.filter(i => i.status === 'overdue').length,
    totalAmount: invoices.reduce((sum, i) => sum + i.amount, 0),
    paidAmount: invoices.filter(i => i.status === 'paid').reduce((sum, i) => sum + i.amount, 0),
  }), []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Invoices</h1>
          <p className="text-muted-foreground">Manage rental invoices</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline">
            <Plus className="mr-2 h-4 w-4" />
            Create Invoice
          </Button>
          <Button>
            <FileText className="mr-2 h-4 w-4" />
            Generate Monthly
          </Button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{stats.total}</div>
            <p className="text-sm text-muted-foreground">Total Invoices</p>
            <p className="text-lg font-semibold text-primary mt-1">
              {formatCurrency(stats.totalAmount)}
            </p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-success">{stats.paid}</div>
            <p className="text-sm text-muted-foreground">Paid</p>
            <p className="text-lg font-semibold text-success mt-1">
              {formatCurrency(stats.paidAmount)}
            </p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-warning">{stats.pending}</div>
            <p className="text-sm text-muted-foreground">Pending</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-destructive">{stats.overdue}</div>
            <p className="text-sm text-muted-foreground">Overdue</p>
          </CardContent>
        </Card>
      </div>

      {/* Filters & Table */}
      <Card className="shadow-card">
        <CardHeader className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between space-y-0">
          <CardTitle className="text-lg">All Invoices</CardTitle>
          <div className="flex gap-2">
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[130px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="paid">Paid</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="overdue">Overdue</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Invoice #</TableHead>
                <TableHead>Tenant</TableHead>
                <TableHead>Property</TableHead>
                <TableHead>Issue Date</TableHead>
                <TableHead>Due Date</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredInvoices.map((invoice) => {
                const tenant = getTenantById(invoice.tenantId);
                const property = getPropertyById(invoice.propertyId);
                const daysOverdue = getDaysOverdue(invoice.dueDate);

                return (
                  <TableRow 
                    key={invoice.id}
                    className={invoice.status === 'overdue' && daysOverdue > 30 ? "bg-destructive/5" : ""}
                  >
                    <TableCell className="font-mono font-medium">{invoice.id}</TableCell>
                    <TableCell>{tenant?.name}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {property?.name}
                    </TableCell>
                    <TableCell>{formatDate(invoice.issueDate)}</TableCell>
                    <TableCell>{formatDate(invoice.dueDate)}</TableCell>
                    <TableCell className="font-medium">
                      {formatCurrency(invoice.amount)}
                    </TableCell>
                    <TableCell>
                      <StatusBadge variant={invoice.status}>
                        {invoice.status.charAt(0).toUpperCase() + invoice.status.slice(1)}
                      </StatusBadge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button variant="ghost" size="icon">
                          <Eye className="h-4 w-4" />
                        </Button>
                        <Button variant="ghost" size="icon">
                          <Download className="h-4 w-4" />
                        </Button>
                        {invoice.status !== 'paid' && (
                          <>
                            <Button variant="ghost" size="icon">
                              <Check className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="icon">
                              <Send className="h-4 w-4" />
                            </Button>
                          </>
                        )}
                      </div>
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

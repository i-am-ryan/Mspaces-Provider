import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { 
  properties, 
  tenants, 
  invoices, 
  payments, 
  expenses,
  getPropertyById,
  getTenantById 
} from "@/data/mockData";
import { formatCurrency, formatDate } from "@/utils/formatters";
import { Download, FileText, BarChart3 } from "lucide-react";

const reportTypes = [
  { value: "income", label: "Income Statement" },
  { value: "rent-roll", label: "Rent Roll Report" },
  { value: "tenant-payments", label: "Tenant Payment History" },
  { value: "property-performance", label: "Property Performance" },
  { value: "expense-summary", label: "Expense Summary" },
];

export function LandlordReports() {
  const [reportType, setReportType] = useState("income");
  const [dateRange, setDateRange] = useState("month");

  const renderIncomeStatement = () => {
    const totalRent = payments.reduce((sum, p) => sum + p.amount, 0);
    const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
    const netIncome = totalRent - totalExpenses;

    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-3">
          <Card className="shadow-card">
            <CardContent className="pt-6">
              <div className="text-2xl font-bold text-success">{formatCurrency(totalRent)}</div>
              <p className="text-sm text-muted-foreground">Total Revenue</p>
            </CardContent>
          </Card>
          <Card className="shadow-card">
            <CardContent className="pt-6">
              <div className="text-2xl font-bold text-destructive">{formatCurrency(totalExpenses)}</div>
              <p className="text-sm text-muted-foreground">Total Expenses</p>
            </CardContent>
          </Card>
          <Card className="shadow-card bg-primary text-primary-foreground">
            <CardContent className="pt-6">
              <div className="text-2xl font-bold">{formatCurrency(netIncome)}</div>
              <p className="text-sm opacity-90">Net Income</p>
            </CardContent>
          </Card>
        </div>

        <Card className="shadow-card">
          <CardHeader>
            <CardTitle className="text-lg">Revenue Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Property</TableHead>
                  <TableHead className="text-right">Revenue</TableHead>
                  <TableHead className="text-right">Expenses</TableHead>
                  <TableHead className="text-right">Net</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {properties.map(property => {
                  const propPayments = payments.filter(p => {
                    const invoice = invoices.find(i => i.id === p.invoiceId);
                    return invoice?.propertyId === property.id;
                  });
                  const propExpenses = expenses.filter(e => e.propertyId === property.id);
                  const revenue = propPayments.reduce((sum, p) => sum + p.amount, 0);
                  const exp = propExpenses.reduce((sum, e) => sum + e.amount, 0);

                  return (
                    <TableRow key={property.id}>
                      <TableCell className="font-medium">{property.name}</TableCell>
                      <TableCell className="text-right text-success">
                        {formatCurrency(revenue)}
                      </TableCell>
                      <TableCell className="text-right text-destructive">
                        {formatCurrency(exp)}
                      </TableCell>
                      <TableCell className="text-right font-medium">
                        {formatCurrency(revenue - exp)}
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
  };

  const renderRentRoll = () => (
    <Card className="shadow-card">
      <CardHeader>
        <CardTitle className="text-lg">Rent Roll</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Tenant</TableHead>
              <TableHead>Property</TableHead>
              <TableHead>Unit</TableHead>
              <TableHead>Lease End</TableHead>
              <TableHead className="text-right">Monthly Rent</TableHead>
              <TableHead className="text-right">Annual Rent</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {tenants.map(tenant => {
              const property = getPropertyById(tenant.propertyId);
              return (
                <TableRow key={tenant.id}>
                  <TableCell className="font-medium">{tenant.name}</TableCell>
                  <TableCell>{property?.name}</TableCell>
                  <TableCell>{tenant.unitNumber}</TableCell>
                  <TableCell>{formatDate(tenant.leaseEnd)}</TableCell>
                  <TableCell className="text-right">
                    {formatCurrency(tenant.monthlyRent)}
                  </TableCell>
                  <TableCell className="text-right font-medium">
                    {formatCurrency(tenant.monthlyRent * 12)}
                  </TableCell>
                </TableRow>
              );
            })}
            <TableRow className="bg-muted/50">
              <TableCell colSpan={4} className="font-bold">Total</TableCell>
              <TableCell className="text-right font-bold">
                {formatCurrency(tenants.reduce((sum, t) => sum + t.monthlyRent, 0))}
              </TableCell>
              <TableCell className="text-right font-bold">
                {formatCurrency(tenants.reduce((sum, t) => sum + t.monthlyRent * 12, 0))}
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );

  const renderReport = () => {
    switch (reportType) {
      case "income":
        return renderIncomeStatement();
      case "rent-roll":
        return renderRentRoll();
      default:
        return (
          <Card className="shadow-card">
            <CardContent className="flex flex-col items-center justify-center py-12">
              <BarChart3 className="h-12 w-12 text-muted-foreground mb-4" />
              <p className="text-lg font-medium">Report: {reportTypes.find(r => r.value === reportType)?.label}</p>
              <p className="text-sm text-muted-foreground">Click "Generate Report" to view data</p>
            </CardContent>
          </Card>
        );
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Reports</h1>
          <p className="text-muted-foreground">Generate financial reports</p>
        </div>
        <Button>
          <Download className="mr-2 h-4 w-4" />
          Download PDF
        </Button>
      </div>

      {/* Report Controls */}
      <Card className="shadow-card">
        <CardContent className="pt-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
            <div className="flex-1 space-y-2">
              <label className="text-sm font-medium">Report Type</label>
              <Select value={reportType} onValueChange={setReportType}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {reportTypes.map(r => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex-1 space-y-2">
              <label className="text-sm font-medium">Date Range</label>
              <Select value={dateRange} onValueChange={setDateRange}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="month">This Month</SelectItem>
                  <SelectItem value="quarter">This Quarter</SelectItem>
                  <SelectItem value="year">This Year</SelectItem>
                  <SelectItem value="all">All Time</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <Button>
              <FileText className="mr-2 h-4 w-4" />
              Generate Report
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Report Content */}
      {renderReport()}
    </div>
  );
}

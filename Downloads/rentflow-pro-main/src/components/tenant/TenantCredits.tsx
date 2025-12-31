import { useMemo } from "react";
import { useAuth } from "@/context/AuthContext";
import { StatusBadge } from "@/components/ui/status-badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { creditNotes } from "@/data/mockData";
import { formatCurrency, formatDate, getCategoryLabel } from "@/utils/formatters";
import { Gift, Wallet } from "lucide-react";

export function TenantCredits() {
  const { user } = useAuth();

  const tenantCredits = useMemo(() => {
    return creditNotes
      .filter(c => c.tenantId === user?.id)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [user?.id]);

  const availableBalance = useMemo(() => {
    return tenantCredits
      .filter(c => c.status === 'available')
      .reduce((sum, c) => sum + c.amount, 0);
  }, [tenantCredits]);

  const totalCredits = useMemo(() => {
    return tenantCredits.reduce((sum, c) => sum + c.amount, 0);
  }, [tenantCredits]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Credit Notes</h1>
        <p className="text-muted-foreground">View your deposits, refunds, and adjustments</p>
      </div>

      {/* Summary Cards */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="shadow-card bg-primary text-primary-foreground">
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="rounded-lg bg-white/20 p-3">
                <Wallet className="h-6 w-6" />
              </div>
              <div>
                <div className="text-3xl font-bold">{formatCurrency(availableBalance)}</div>
                <p className="text-sm opacity-90">Available Balance</p>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{formatCurrency(totalCredits)}</div>
            <p className="text-sm text-muted-foreground">Total Credits</p>
          </CardContent>
        </Card>
        <Card className="shadow-card">
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{tenantCredits.length}</div>
            <p className="text-sm text-muted-foreground">Credit Notes</p>
          </CardContent>
        </Card>
      </div>

      {/* Credits Table */}
      <Card className="shadow-card">
        <CardHeader>
          <CardTitle className="text-lg">Credit History</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Description</TableHead>
                <TableHead>Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {tenantCredits.map((credit) => (
                <TableRow key={credit.id}>
                  <TableCell className="font-medium">
                    {formatDate(credit.date)}
                  </TableCell>
                  <TableCell>{getCategoryLabel(credit.type)}</TableCell>
                  <TableCell className="font-medium text-success">
                    +{formatCurrency(credit.amount)}
                  </TableCell>
                  <TableCell className="max-w-[200px] truncate">
                    {credit.description}
                  </TableCell>
                  <TableCell>
                    <StatusBadge variant={credit.status}>
                      {credit.status.charAt(0).toUpperCase() + credit.status.slice(1)}
                    </StatusBadge>
                  </TableCell>
                </TableRow>
              ))}
              {tenantCredits.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} className="text-center text-muted-foreground py-8">
                    <Gift className="mx-auto h-12 w-12 text-muted-foreground/50 mb-2" />
                    No credit notes yet
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

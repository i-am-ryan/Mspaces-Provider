import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const statusBadgeVariants = cva(
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors",
  {
    variants: {
      variant: {
        paid: "bg-success/10 text-success border border-success/20",
        pending: "bg-warning/10 text-warning border border-warning/20",
        overdue: "bg-destructive/10 text-destructive border border-destructive/20",
        current: "bg-success/10 text-success border border-success/20",
        expiring: "bg-warning/10 text-warning border border-warning/20",
        occupied: "bg-success/10 text-success border border-success/20",
        vacant: "bg-muted text-muted-foreground border border-border",
        partial: "bg-info/10 text-info border border-info/20",
        available: "bg-success/10 text-success border border-success/20",
        applied: "bg-primary/10 text-primary border border-primary/20",
        refunded: "bg-muted text-muted-foreground border border-border",
      },
    },
    defaultVariants: {
      variant: "pending",
    },
  }
);

export interface StatusBadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof statusBadgeVariants> {
  children: React.ReactNode;
}

function StatusBadge({ className, variant, children, ...props }: StatusBadgeProps) {
  return (
    <div className={cn(statusBadgeVariants({ variant }), className)} {...props}>
      {children}
    </div>
  );
}

export { StatusBadge, statusBadgeVariants };

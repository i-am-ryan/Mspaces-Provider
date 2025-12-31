import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import { LucideIcon } from "lucide-react";

const kpiCardVariants = cva(
  "rounded-lg p-6 shadow-card transition-all hover:shadow-card-hover",
  {
    variants: {
      variant: {
        default: "bg-card",
        primary: "bg-primary text-primary-foreground",
        success: "bg-success text-success-foreground",
        warning: "bg-warning text-warning-foreground",
        destructive: "bg-destructive text-destructive-foreground",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
);

export interface KpiCardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof kpiCardVariants> {
  title: string;
  value: string | number;
  subtitle?: string;
  icon?: LucideIcon;
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

function KpiCard({
  className,
  variant,
  title,
  value,
  subtitle,
  icon: Icon,
  trend,
  ...props
}: KpiCardProps) {
  const isColoredVariant = variant && variant !== "default";
  
  return (
    <div className={cn(kpiCardVariants({ variant }), className)} {...props}>
      <div className="flex items-start justify-between">
        <div className="space-y-2">
          <p className={cn(
            "text-sm font-medium",
            isColoredVariant ? "opacity-90" : "text-muted-foreground"
          )}>
            {title}
          </p>
          <p className="text-2xl font-bold tracking-tight">{value}</p>
          {subtitle && (
            <p className={cn(
              "text-xs",
              isColoredVariant ? "opacity-80" : "text-muted-foreground"
            )}>
              {subtitle}
            </p>
          )}
          {trend && (
            <div className={cn(
              "flex items-center text-xs font-medium",
              trend.isPositive 
                ? (isColoredVariant ? "opacity-90" : "text-success") 
                : (isColoredVariant ? "opacity-90" : "text-destructive")
            )}>
              <span>{trend.isPositive ? "↑" : "↓"} {Math.abs(trend.value)}%</span>
              <span className={cn(
                "ml-1",
                isColoredVariant ? "opacity-70" : "text-muted-foreground"
              )}>vs last month</span>
            </div>
          )}
        </div>
        {Icon && (
          <div className={cn(
            "rounded-lg p-3",
            isColoredVariant ? "bg-white/20" : "bg-primary/10"
          )}>
            <Icon className={cn(
              "h-5 w-5",
              isColoredVariant ? "text-current" : "text-primary"
            )} />
          </div>
        )}
      </div>
    </div>
  );
}

export { KpiCard, kpiCardVariants };
